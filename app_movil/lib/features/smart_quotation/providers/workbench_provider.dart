import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert';
import 'package:intl/intl.dart'; 
import '../../../config/api_constants.dart';
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';
import '../services/quotation_service.dart';

enum WorkbenchSort { time, alpha }

class WorkbenchProvider with ChangeNotifier {
  String? _authToken;
  bool _isLoading = false;
  String _errorMessage = "";
  
  // 🔥 FASE 3: Callback para notificar a la UI si el usuario es expulsado
  Function()? onAuthRevoked;

  final QuotationService _quotationService = QuotationService();
  
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

  void updateToken(String? token) {
    _authToken = token;
  }

  // 🔥 Helper para manejar la expulsión en el catch
  void _handleException(dynamic e) {
    if (e.toString().contains("AUTH_REVOKED")) {
      _errorMessage = "Tu acceso a este negocio ha sido revocado.";
      if (onAuthRevoked != null) onAuthRevoked!();
    } else {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
    }
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
    if (_authToken == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _allQuotations = data.map((e) => SmartQuotationModel.fromJson(e)).toList();
        _organizeLists();
        _evaluateHealthAndAutoDowngrade();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
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
      if (inst.contains('venta al paso pos') || inst.contains('venta al paso')) {
        return false;
      }
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
    if (_authToken == null) return;
    try {
      final result = await _quotationService.validateIntegrity(quotationId, _authToken!);
      _trafficLights[quotationId] = result;
      notifyListeners(); 
    } catch (e) {
      // No silenciamos el auth revoked
      if (e.toString().contains("AUTH_REVOKED")) _handleException(e);
    }
  }

  ValidationResult? getValidationFor(int id) => _trafficLights[id];
  
  Future<int?> saveManualQuotation({
    int? id, int? clientId, String? clientName, String? institution, String? grade,
    String? notas, 
    required List<Map<String, dynamic>> items, required double totalAmount,
    double totalSavings = 0.0, String status = "DRAFT", String type = "manual",
  }) async {
    if (_authToken == null) return null;
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
        token: _authToken!, 
        id: id, 
        clientId: clientId, 
        clientName: clientName,  
        institutionName: institution, 
        gradeLevel: grade, 
        notas: notas, 
        totalAmount: totalAmount,
        totalSavings: totalSavings, 
        items: items, 
        status: status, 
        type: type,
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
    if (_authToken == null) return false;
    try {
      final success = await _quotationService.updateQuotationStatus(id, newStatus, _authToken!);
      if (success && !skipReload) await loadDashboard(); 
      return success;
    } catch (e) { 
      _handleException(e);
      return false; 
    }
  }

  Future<bool> refreshQuotation(int id, {bool fixPrices = true, bool fixStock = false}) async {
    if (_authToken == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _quotationService.refreshQuotation(id, _authToken!, fixPrices: fixPrices, fixStock: fixStock);
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
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id/clone');
      final response = await http.post(url, headers: {'Authorization': 'Bearer $_authToken', 'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        await loadDashboard();
        return data['id']; 
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      return null;
    } catch (e) { 
      _handleException(e);
      return null; 
    } finally { 
      _isLoading = false; notifyListeners(); 
    }
  }

  Future<int?> convertToPack(int id) async {
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id/to-pack');
      final response = await http.post(url, headers: {'Authorization': 'Bearer $_authToken', 'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        await loadDashboard();
        return data['id']; 
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      return null;
    } catch (e) { 
      _handleException(e);
      return null; 
    } finally { 
      _isLoading = false; notifyListeners(); 
    }
  }

  Future<bool> deleteQuotation(int id) async {
    if (_authToken == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      try {
         await _quotationService.updateQuotationStatus(id, 'DRAFT', _authToken!);
      } catch (_) {}
      
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $_authToken'});
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        await loadDashboard(); 
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      throw Exception("Error deleting");
    } catch (e) {
      _handleException(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameQuotation(int id, String newName, {int? clientId}) async {
    if (_authToken == null) return false;
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id');
      
      final Map<String, dynamic> bodyData = {"client_name": newName};
      if (clientId != null) {
        bodyData["client_id"] = clientId;
      }

      final response = await http.patch(
        url,
        headers: {'Authorization': 'Bearer $_authToken', 'Content-Type': 'application/json'},
        body: json.encode(bodyData), 
      );
      if (response.statusCode == 200) {
        await loadDashboard(); 
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      return false;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }
}