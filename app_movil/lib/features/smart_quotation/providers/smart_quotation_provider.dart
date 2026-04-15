import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../config/api_constants.dart'; 
import '../models/extracted_list_model.dart'; 
import '../models/smart_quotation_model.dart'; 
import '../models/matching_model.dart';
import '../models/crm_models.dart';
import '../services/ai_extraction_service.dart';
import 'matching_provider.dart';
import '../services/client_service.dart';

class SmartQuotationProvider with ChangeNotifier {
  final AIExtractionService _service = AIExtractionService();
  final ClientService _clientService = ClientService(); 
  
  Function()? onAuthRevoked;

  bool _isLoading = false;
  String _errorMessage = '';
  String? _authToken; 

  File? _currentImage;
  ExtractedMetadata? _metadata;
  List<ExtractedItem> _items = [];

  List<MatchedProduct>? draftManualItems;
  Map<int, int>? draftManualQuantities;
  Map<int, double>? draftManualPrices;
  Map<int, String>? draftManualNames;
  
  ClientModel? draftClient;
  
  String? draftClientName;
  String? draftClientPhone;
  String? draftClientDni;
  String? draftClientAddress;
  String? draftClientEmail;
  String? draftClientNotes;
  
  String? draftQuoteTitle;  
  String? draftQuoteNotes;  
  String? draftSchool;
  String? draftGrade;
  
  int? draftQuotationId; 

  bool get hasManualDraft => draftManualItems != null && draftManualItems!.isNotEmpty;

  void _handleException(dynamic e) {
    if (e.toString().contains("AUTH_REVOKED")) {
      _errorMessage = "Tu acceso a este negocio ha sido revocado.";
      if (onAuthRevoked != null) onAuthRevoked!();
    } else {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
    }
  }

  void saveManualDraft({
    required List<MatchedProduct> items,
    required Map<int, int> quantities,
    required Map<int, double> prices,
    required Map<int, String> names,
    ClientModel? client,
    String? cName, String? cPhone, String? cDni, String? cAddr, String? cEmail, String? cNotes,
    String? qTitle, String? qNotes, 
    String? school, String? grade,
    int? quotationId,
  }) {
    draftManualItems = List.from(items);
    draftManualQuantities = Map.from(quantities);
    draftManualPrices = Map.from(prices);
    draftManualNames = Map.from(names);
    
    draftClient = client;
    draftClientName = cName;
    draftClientPhone = cPhone;
    draftClientDni = cDni;
    draftClientAddress = cAddr;
    draftClientEmail = cEmail;
    draftClientNotes = cNotes;
    
    draftQuoteTitle = qTitle;
    draftQuoteNotes = qNotes;
    draftSchool = school;
    draftGrade = grade;
    draftQuotationId = quotationId;
  }

  void clearManualDraft() {
    draftManualItems = null;
    draftManualQuantities = null;
    draftManualPrices = null;
    draftManualNames = null;
    draftClient = null;
    draftClientName = null;
    draftClientPhone = null;
    draftClientDni = null;
    draftClientAddress = null;
    draftClientEmail = null;
    draftClientNotes = null;
    draftQuoteTitle = null;
    draftQuoteNotes = null;
    draftSchool = null;
    draftGrade = null;
    draftQuotationId = null;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  File? get currentImage => _currentImage;
  ExtractedMetadata? get metadata => _metadata;
  List<ExtractedItem> get items => _items;

  String get fullExtractedText {
      if (_items.isEmpty) return "";
      return _items.map((i) => i.originalText).join("\n");
  }

  void updateToken(String? token) {
    _authToken = token;
  }

  void clearState() {
    _items = [];
    _metadata = null;
    _currentImage = null;
    _errorMessage = '';
    notifyListeners();
  }

  Future<bool> analyzeImage(BuildContext context, File image, String token) async {
    Provider.of<MatchingProvider>(context, listen: false).clearState();
    _isLoading = true;
    _errorMessage = '';
    _currentImage = image;
    notifyListeners();

    try {
      final response = await _service.analyzeImage(image, token);
      _metadata = response.metadata;
      _items = response.items;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _handleException(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void updateItem(int id, {String? fullName, String? brand, int? quantity, String? unit, String? notes}) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      if (fullName != null) item.fullName = fullName;
      if (brand != null) item.brand = brand;
      if (quantity != null) item.quantity = quantity;
      if (unit != null) item.unit = unit;
      if (notes != null) item.notes = notes;
      notifyListeners();
    }
  }

  void deleteItem(int id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addItem() {
    int newId = _items.isNotEmpty ? _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1 : 1;
    _items.add(ExtractedItem(
      id: newId,
      originalText: "Agregado manual",
      fullName: "",
      quantity: 1,
      unit: "unidad"
    ));
    notifyListeners();
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _metadata ??= ExtractedMetadata();
    if (institution != null) _metadata!.institutionName = institution;
    if (student != null) _metadata!.studentName = student;
    if (grade != null) _metadata!.gradeLevel = grade;
    notifyListeners();
  }

  Future<SmartQuotationModel?> getQuotationById(int id) async {
    if (_authToken == null) return null;
    final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$id');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_authToken', 'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return SmartQuotationModel.fromJson(data);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception("AUTH_REVOKED");
      }
      return null;
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  // 🔥 NUEVA LÓGICA: Inyecta explícitamente si fue manual o IA en el nombre
  Future<String> generateDynamicQuoteName(ClientModel? selectedClient, String tempName, {bool isClientRole = false, String? clientUserName, required String type}) async {
      final timeStr = DateFormat('dd-HHmm').format(DateTime.now()); 
      final String typeLabel = type == 'ai_scan' ? "IA" : "Manual";

      if (isClientRole) {
          final String name = (clientUserName != null && clientUserName.isNotEmpty) ? clientUserName : "Cliente";
          return "$name - Pedido $typeLabel #$timeStr"; 
      }

      if (selectedClient == null && tempName.isEmpty) {
          return "Cotización $typeLabel #$timeStr";
      }

      if (selectedClient != null) {
         if (_authToken == null) return "${selectedClient.fullName} - Cotización $typeLabel #$timeStr";
         try {
            final list = await _clientService.getPendingQuotations(selectedClient.id, _authToken!);
            int count = list.length + 1;
            
            if (count > 1) {
                return "${selectedClient.fullName} #$timeStr ($count) - $typeLabel";
            } else {
                return "${selectedClient.fullName} #$timeStr - $typeLabel";
            }
         } catch(e) {
            return "${selectedClient.fullName} - Cotización $typeLabel #$timeStr";
         }
      }

      return "$tempName #$timeStr";
  }
}