import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart'; 
import 'package:app_movil/features/smart_quotation/services/matching_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/repositories/promotion_repository.dart';

class MatchingProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  final MatchingService _service = MatchingService();
  final ClientService _clientService = ClientService();
  final PromotionRepository _promoRepo = PromotionRepository();

  List<BundleModel> _activeBundles = [];
  final Map<int, List<BundleItemModel>> _bundleItemsCache = {};

  bool _isLoading = false;
  bool _isSaving = false;
  String _errorMessage = '';
  List<MatchPair> _pairs = [];

  List<MatchPair> _originalPairs = [];
  ExtractedMetadata? _originalMetadata;
  bool _hasModifications = false;

  ExtractedMetadata? _metadata;
  ClientModel? _selectedClient; 
  
  File? _localImageFile; 
  String? _fullExtractedText; 

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get errorMessage => _errorMessage;
  List<MatchPair> get pairs => _pairs;
  ExtractedMetadata? get metadata => _metadata;
  ClientModel? get selectedClient => _selectedClient;
  bool get hasModifications => _hasModifications;
  List<BundleModel> get activeBundles => _activeBundles;
  Map<int, List<BundleItemModel>> get bundleItemsCache => _bundleItemsCache;

  double get totalNetAmount {
    final total = _pairs.fold(0.0, (sum, pair) => sum + pair.subtotal);
    return double.parse(total.toStringAsFixed(2));
  }

  double get totalSavingsAmount {
    final total = _pairs.fold(0.0, (sum, pair) => sum + pair.totalSavings);
    return double.parse(total.toStringAsFixed(2));
  }

  int get matchedCount => _pairs.where((p) => p.selectedProduct != null).length;
  bool get hasStockWarnings => _pairs.any((p) => p.hasStockWarning);

  bool isProductRepeated(int? presentationId) {
    if (presentationId == null) return false;
    int count = _pairs.where((p) => p.selectedProduct?.presentationId == presentationId).length;
    return count > 1;
  }

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      clearState();
    }
  }

  void clearState() {
    _pairs.clear(); _originalPairs.clear(); _metadata = null; _originalMetadata = null;
    _selectedClient = null; _localImageFile = null; _fullExtractedText = null;
    _isLoading = false; _isSaving = false; _hasModifications = false; _errorMessage = '';
    notifyListeners();
  }

  void setEvidence(File? image, String? fullText) {
      _localImageFile = image;
      _fullExtractedText = fullText;
  }

  void resetToInitialState() {
    _pairs = _originalPairs.map((p) => p.clone()).toList();
    _metadata = _originalMetadata?.clone();
    _selectedClient = null; 
    _hasModifications = false;
    notifyListeners();
  }

  Future<void> initializeAndMatch(List<ExtractedItem> sourceItems, ExtractedMetadata? meta, {bool isClientRole = false}) async {
    if (_pairs.isNotEmpty || _negocioId == null) return;
    _isLoading = true;
    _errorMessage = '';

    _metadata = ExtractedMetadata(
      institutionName: meta?.institutionName ?? "", studentName: meta?.studentName ?? "", gradeLevel: meta?.gradeLevel ?? "",
    );

    _pairs = sourceItems.map((item) => MatchPair(sourceItem: item)).toList();
    notifyListeners();

    try {
      final results = await _service.runBatchMatching(sourceItems, _negocioId!, isClientRole); 

      for (var result in results) {
        final index = _pairs.indexWhere((p) => p.sourceItem.id == result.itemId);
        if (index != -1) {
          final pair = _pairs[index];
          
          if (result.suggestedProduct != null) {
            pair.selectedProduct = result.suggestedProduct;
            if (result.suggestedQuantity != null) pair.selectedQuantity = result.suggestedQuantity!;

            if (isClientRole) {
                if (pair.selectedProduct!.stock <= 0) {
                    pair.selectedProduct = null;
                    pair.status = MatchStatus.none;
                    continue; 
                } else if (pair.selectedQuantity > pair.selectedProduct!.stock) {
                    pair.selectedQuantity = pair.selectedProduct!.stock;
                }
            }

            if (result.matchTypeString == 'AUTO') { pair.status = MatchStatus.auto; } 
            else if (result.matchTypeString == 'SUGGESTION') { pair.status = MatchStatus.suggestion; } 
            else { pair.status = MatchStatus.none; }
          }
        }
      }
      
      await _loadActiveBundles();
      _detectAndApplyBundles();
      
      _originalPairs = _pairs.map((p) => p.clone()).toList();
      _originalMetadata = _metadata?.clone();
      _hasModifications = false;

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _metadata ??= ExtractedMetadata();
    if (institution != null) _metadata!.institutionName = institution;
    if (student != null) _metadata!.studentName = student;
    if (grade != null) _metadata!.gradeLevel = grade;
    _hasModifications = true;
    notifyListeners();
  }

  Future<void> _loadActiveBundles() async {
    if (_negocioId == null) return;
    try {
      final bunRows = await _promoRepo.getBundles(_negocioId!);
      _activeBundles = bunRows.map((e) => BundleModel.fromJson(e)).where((b) {
        if (!b.activo) return false;
        final now = DateTime.now();
        if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) return false;
        if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
        return true;
      }).toList();

      _bundleItemsCache.clear();
      for (var bundle in _activeBundles) {
        final itemsRows = await _promoRepo.getBundleItems(bundle.id);
        _bundleItemsCache[bundle.id] = itemsRows.map((e) => BundleItemModel.fromJson(e)).toList();
      }
    } catch(e) {
      // Ignorar error al cargar bundles
    }
  }

  void _detectAndApplyBundles() {
    // 1. Reset all bundleIds
    for (var pair in _pairs) {
      pair.bundleId = null;
      pair.bundleName = null;
      pair.overridePrice = null; // Reiniciar
    }
    
    // 2. Revisar cada paquete activo
    for (var bundle in _activeBundles) {
      final requiredItems = _bundleItemsCache[bundle.id] ?? [];
      if (requiredItems.isEmpty) continue;
      
      // Buscar si tenemos todos los productos requeridos con la cantidad requerida (simplificado: al menos 1 unidad requerida encontrada)
      List<MatchPair> matchedPairsForBundle = [];
      bool canFormBundle = true;
      
      for (var req in requiredItems) {
        final found = _pairs.where((p) => p.selectedProduct?.productId == req.productoId).toList();
        if (found.isEmpty) {
          canFormBundle = false;
          break;
        } else {
          matchedPairsForBundle.addAll(found);
        }
      }
      
      if (canFormBundle && matchedPairsForBundle.length == requiredItems.length) { // Validación estricta 1 a 1 para simplificar
        // Agruparlos
        // Agruparlos evaluando el precio que realmente tiene aplicado el producto
        double totalEffective = matchedPairsForBundle.fold(0.0, (sum, p) => sum + (p.effectiveUnitPrice * p.selectedQuantity));
        
        if (totalEffective > 0 && bundle.precioVentaTotal < totalEffective) {
          double discountFactor = bundle.precioVentaTotal / totalEffective;
          for (var p in matchedPairsForBundle) {
            double proposedPrice = p.effectiveUnitPrice * discountFactor;
            // Solo aplicamos si el precio del paquete realmente beneficia a este producto
            if (proposedPrice < p.effectiveUnitPrice) {
              p.bundleId = bundle.id;
              p.bundleName = bundle.nombrePaquete;
              p.overridePrice = proposedPrice;
            }
          }
        }
      }
    }
  }

  void toggleBundleGrouping(int bundleId, bool group) {
    for (var pair in _pairs) {
      if (group) {
        // En un caso real, reejecutaríamos _detectAndApplyBundles para ese bundle. 
        // Para simplificar, relanzamos la detección global:
        _detectAndApplyBundles();
        break;
      } else {
        if (pair.bundleId == bundleId) {
          pair.bundleId = null;
          pair.bundleName = null;
          pair.overridePrice = null;
        }
      }
    }
    _hasModifications = true;
    notifyListeners();
  }

  void setClient(ClientModel? client) {
    _selectedClient = client;
    if (client != null) _metadata?.studentName = client.fullName;
    _hasModifications = true;
    notifyListeners();
  }

  void updatePairProduct(int itemId, MatchedProduct product) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedProduct = product;
      _pairs[index].overridePrice = null;
      _pairs[index].status = MatchStatus.manual;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairPrice(int itemId, double? newPrice) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].overridePrice = newPrice;
      _pairs[index].status = MatchStatus.manual;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairQuantity(int itemId, int newQuantity) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedQuantity = newQuantity;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void unmatchItem(int itemId) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedProduct = null;
      _pairs[index].overridePrice = null;
      _pairs[index].status = MatchStatus.none;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void deletePair(int itemId) {
    _pairs.removeWhere((p) => p.sourceItem.id == itemId);
    _hasModifications = true;
    notifyListeners();
  }

  void addManualRow() {
    int maxId = 0;
    if (_pairs.isNotEmpty) maxId = _pairs.map((p) => p.sourceItem.id).reduce((curr, next) => curr > next ? curr : next);
    final newItem = ExtractedItem(id: maxId + 1, originalText: "Agregado Manual", fullName: "Nuevo Ítem", quantity: 1, unit: "und");
    _pairs.add(MatchPair(sourceItem: newItem, status: MatchStatus.none));
    _hasModifications = true;
    notifyListeners();
  }

  Future<int?> saveQuotation(
    String status, {
      String? manualClientName, String? manualClientPhone, String? manualClientDni, String? manualClientAddress, String? manualClientEmail, String? manualClientNotes,
      bool updateClientData = true, String? institutionName, String? gradeLevel, String? type, bool isClientRole = false, 
    }
  ) async {
    if (_negocioId == null || _usuarioId == null) return null;
    
    _isSaving = true;
    notifyListeners();

    try {
      if (_pairs.isEmpty) {
        _errorMessage = "No se puede guardar una lista vacía";
        return null;
      }

      _metadata ??= ExtractedMetadata();
      if (institutionName != null && institutionName.isNotEmpty) _metadata!.institutionName = institutionName;
      if (gradeLevel != null && gradeLevel.isNotEmpty) _metadata!.gradeLevel = gradeLevel;

      String? uploadedImageUrl;
      if (_localImageFile != null) {
          uploadedImageUrl = await _service.uploadImageToBackend(_localImageFile!);
      }

      final List<Map<String, dynamic>> validItems = [];

      for (var p in _pairs.where((p) => p.selectedProduct != null)) {
        var itemJson = p.toQuotationItemJson(); 
        if (itemJson != null) {
          itemJson['original_text'] = p.sourceItem.originalText;
          validItems.add(itemJson);
        }
      }

      if (validItems.isEmpty) {
        _errorMessage = "Selecciona al menos un producto para guardar.";
        return null;
      }

      int? finalClientId = (_selectedClient?.id == 0) ? null : _selectedClient?.id;
      String rawClientName = _selectedClient?.fullName ?? manualClientName?.trim() ?? "";

      if (!isClientRole && updateClientData && rawClientName.isNotEmpty) {
        final clientData = {
          'nombre_completo': rawClientName, 'telefono': manualClientPhone?.replaceAll(" ", "") ?? "",
          'dni_ruc': manualClientDni?.trim(), 'direccion': manualClientAddress?.trim(),
          'correo': manualClientEmail?.trim(), 'notas': manualClientNotes?.trim()
        };
        
        try {
          if (_selectedClient != null && _selectedClient!.id != 0) {
            await _clientService.updateClient(_selectedClient!.id, clientData);
          } else {
            final newClient = await _clientService.createClient(clientData, _negocioId!, _usuarioId!);
            finalClientId = newClient.id; 
          }
        } catch (e) {
          debugPrint("Error guardando cliente CRM: $e");
        }
      }

      final timeStr = DateFormat('dd-HHmm').format(DateTime.now()); 
      String finalQuoteName = "";
      String typeLabel = type == "ai_scan" ? "IA" : "Manual";

      if (isClientRole) {
          final String name = (manualClientName != null && manualClientName.isNotEmpty) ? manualClientName : "Cliente";
          finalQuoteName = "$name - Pedido $typeLabel #$timeStr"; 
      } else {
          if (rawClientName.isEmpty) {
              finalQuoteName = "Cotización $typeLabel #$timeStr";
          } else {
              if (finalClientId != null) {
                 try {
                    final list = await _clientService.getPendingQuotations(finalClientId);
                    int count = list.length + 1;
                    finalQuoteName = "$rawClientName #$timeStr ($count) - $typeLabel";
                 } catch(e) {
                    finalQuoteName = "$rawClientName #$timeStr - $typeLabel";
                 }
              } else {
                 finalQuoteName = "$rawClientName #$timeStr - $typeLabel";
              }
          }
      }

      double finalAmount = 0.0;
      double finalSavings = 0.0;
      for(var item in validItems) {
        finalAmount += (item['unit_price_applied'] * item['quantity']);
        double originalTotal = item['original_unit_price'] * item['quantity'];
        finalSavings += (originalTotal - (item['unit_price_applied'] * item['quantity']));
      }

      final quotationPayload = {
        "client_id": finalClientId, 
        "client_name": finalQuoteName, 
        "institution_name": _metadata?.institutionName,
        "grade_level": _metadata?.gradeLevel,
        "total_amount": double.parse(finalAmount.toStringAsFixed(2)),
        "total_savings": double.parse(finalSavings.toStringAsFixed(2)),
        "status": status, 
        "type": type ?? "ai_scan",
        "source_image_url": uploadedImageUrl, 
        "items": validItems,
        "original_text_dump": _fullExtractedText 
      };

      final newId = await _service.saveQuotation(quotationPayload, _negocioId!, _usuarioId!);
      return newId;

    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}