import 'dart:io'; 
import 'package:flutter/material.dart';

import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart'; 
import 'package:app_movil/features/smart_quotation/services/matching_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/repositories/promotion_repository.dart';

class MatchingState {
  List<BundleModel> activeBundles = [];
  final Map<int, List<BundleItemModel>> bundleItemsCache = {};

  bool isLoading = false;
  bool isSaving = false;
  String errorMessage = '';
  List<MatchPair> pairs = [];

  List<MatchPair> originalPairs = [];
  ExtractedMetadata? originalMetadata;
  bool hasModifications = false;

  ExtractedMetadata? metadata;
  ClientModel? selectedClient; 
  
  File? localImageFile; 
  String? fullExtractedText; 
}

class MatchingProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  final MatchingService _service = MatchingService();
  final ClientService _clientService = ClientService();
  final PromotionRepository _promoRepo = PromotionRepository();

  final Map<int, MatchingState> _states = {};

  MatchingState get _currentState {
    final key = _negocioId ?? 0;
    return _states.putIfAbsent(key, () => MatchingState());
  }

  bool get isLoading => _currentState.isLoading;
  bool get isSaving => _currentState.isSaving;
  String get errorMessage => _currentState.errorMessage;
  List<MatchPair> get pairs => _currentState.pairs;
  ExtractedMetadata? get metadata => _currentState.metadata;
  ClientModel? get selectedClient => _currentState.selectedClient;
  bool get hasModifications => _currentState.hasModifications;
  List<BundleModel> get activeBundles => _currentState.activeBundles;
  Map<int, List<BundleItemModel>> get bundleItemsCache => _currentState.bundleItemsCache;

  double get totalNetAmount {
    final total = _currentState.pairs.fold(0.0, (sum, pair) => sum + pair.subtotal);
    return double.parse(total.toStringAsFixed(2));
  }

  double get totalSavingsAmount {
    final total = _currentState.pairs.fold(0.0, (sum, pair) => sum + pair.totalSavings);
    return double.parse(total.toStringAsFixed(2));
  }

  int get matchedCount => _currentState.pairs.where((p) => p.selectedProduct != null).length;
  Map<int, int> get sharedDemandPerProduct {
    final Map<int, int> demand = {};
    for (final pair in _currentState.pairs) {
      final p = pair.selectedProduct;
      if (p != null && p.usaStockCompartido && p.productId > 0) {
        final factor = p.conversionFactor > 0 ? p.conversionFactor : 1;
        demand[p.productId] = (demand[p.productId] ?? 0) + (pair.selectedQuantity * factor);
      }
    }
    return demand;
  }

  bool isSharedPoolExceeded(int productId, int poolCapacity) {
    if (productId <= 0 || poolCapacity <= 0) return false;
    final demand = sharedDemandPerProduct[productId] ?? 0;
    return demand > poolCapacity;
  }

  bool get hasStockWarnings {
    final sharedDemand = sharedDemandPerProduct;
    for (final pair in _currentState.pairs) {
      if (pair.hasStockWarning) return true;
      final p = pair.selectedProduct;
      if (p != null && p.usaStockCompartido && p.productId > 0 && p.sharedStockPool > 0) {
        final demand = sharedDemand[p.productId] ?? 0;
        if (demand > p.sharedStockPool) return true;
      }
    }
    return false;
  }

  bool isProductRepeated(int? presentationId) {
    if (presentationId == null) return false;
    int count = _currentState.pairs.where((p) => p.selectedProduct?.presentationId == presentationId).length;
    return count > 1;
  }

  void _handleException(dynamic e) {
    _currentState.errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      Future.microtask(() {
        notifyListeners(); // Notificar para que tome el nuevo estado
      });
    }
    _usuarioId = usuarioId;
  }

  void clearState() {
    _currentState.pairs.clear(); _currentState.originalPairs.clear(); _currentState.metadata = null; _currentState.originalMetadata = null;
    _currentState.selectedClient = null; _currentState.localImageFile = null; _currentState.fullExtractedText = null;
    _currentState.isLoading = false; _currentState.isSaving = false; _currentState.hasModifications = false; _currentState.errorMessage = '';
    notifyListeners();
  }

  void setEvidence(File? image, String? fullText) {
      _currentState.localImageFile = image;
      _currentState.fullExtractedText = fullText;
  }

  void resetToInitialState() {
    _currentState.pairs = _currentState.originalPairs.map((p) => p.clone()).toList();
    _currentState.metadata = _currentState.originalMetadata?.clone();
    _currentState.selectedClient = null; 
    _currentState.hasModifications = false;
    notifyListeners();
  }

  Future<void> initializeAndMatch(List<ExtractedItem> sourceItems, ExtractedMetadata? meta, {bool isClientRole = false}) async {
    final activeState = _currentState;
    final activeNegocioId = _negocioId;
    if (activeState.pairs.isNotEmpty || activeNegocioId == null) return;
    activeState.isLoading = true;
    activeState.errorMessage = '';

    activeState.metadata = ExtractedMetadata(
      institutionName: meta?.institutionName ?? "", studentName: meta?.studentName ?? "", gradeLevel: meta?.gradeLevel ?? "",
    );

    activeState.pairs = sourceItems.map((item) => MatchPair(sourceItem: item)).toList();
    notifyListeners();

    try {
      final results = await _service.runBatchMatching(sourceItems, activeNegocioId, isClientRole); 

      for (var result in results) {
        final index = activeState.pairs.indexWhere((p) => p.sourceItem.id == result.itemId);
        if (index != -1) {
          final pair = activeState.pairs[index];
          
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
      
      activeState.originalPairs = activeState.pairs.map((p) => p.clone()).toList();
      activeState.originalMetadata = activeState.metadata?.clone();
      activeState.hasModifications = false;

    } catch (e) {
      _handleException(e);
    } finally {
      activeState.isLoading = false;
      notifyListeners();
    }
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _currentState.metadata ??= ExtractedMetadata();
    if (institution != null) _currentState.metadata!.institutionName = institution;
    if (student != null) _currentState.metadata!.studentName = student;
    if (grade != null) _currentState.metadata!.gradeLevel = grade;
    _currentState.hasModifications = true;
    notifyListeners();
  }

  Future<void> _loadActiveBundles() async {
    if (_negocioId == null) return;
    try {
      final bunRows = await _promoRepo.getBundles(_negocioId!);
      _currentState.activeBundles = bunRows.map((e) => BundleModel.fromJson(e)).where((b) {
        if (!b.activo) return false;
        final now = DateTime.now();
        if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) return false;
        if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
        return true;
      }).toList();

      _currentState.bundleItemsCache.clear();
      for (var bundle in _currentState.activeBundles) {
        final itemsRows = await _promoRepo.getBundleItems(bundle.id);
        _currentState.bundleItemsCache[bundle.id] = itemsRows.map((e) => BundleItemModel.fromJson(e)).toList();
      }
    } catch(e) {
      // Ignorar error al cargar bundles
    }
  }

  void _detectAndApplyBundles() {
    // 1. Reset all bundleIds
    for (var pair in _currentState.pairs) {
      pair.bundleId = null;
      pair.bundleName = null;
      pair.overridePrice = null; // Reiniciar
    }
    
    // 2. Revisar cada paquete activo
    for (var bundle in _currentState.activeBundles) {
      final requiredItems = _currentState.bundleItemsCache[bundle.id] ?? [];
      if (requiredItems.isEmpty) continue;
      
      // Buscar si tenemos todos los productos requeridos con la cantidad requerida (simplificado: al menos 1 unidad requerida encontrada)
      List<MatchPair> matchedPairsForBundle = [];
      bool canFormBundle = true;
      
      for (var req in requiredItems) {
        final found = _currentState.pairs.where((p) => p.selectedProduct?.productId == req.productoId).toList();
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
    for (var pair in _currentState.pairs) {
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
    _currentState.hasModifications = true;
    notifyListeners();
  }

  void setClient(ClientModel? client) {
    _currentState.selectedClient = client;
    if (client != null) _currentState.metadata?.studentName = client.fullName;
    _currentState.hasModifications = true;
    notifyListeners();
  }

  void updatePairProduct(int itemId, MatchedProduct product) {
    final index = _currentState.pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _currentState.pairs[index].selectedProduct = product;
      _currentState.pairs[index].overridePrice = null;
      _currentState.pairs[index].status = MatchStatus.manual;
      _currentState.hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairPrice(int itemId, double? newPrice) {
    final index = _currentState.pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _currentState.pairs[index].overridePrice = newPrice;
      _currentState.pairs[index].status = MatchStatus.manual;
      _currentState.hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairQuantity(int itemId, int newQuantity) {
    final index = _currentState.pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _currentState.pairs[index].selectedQuantity = newQuantity;
      _currentState.hasModifications = true;
      notifyListeners();
    }
  }

  void unmatchItem(int itemId) {
    final index = _currentState.pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _currentState.pairs[index].selectedProduct = null;
      _currentState.pairs[index].overridePrice = null;
      _currentState.pairs[index].status = MatchStatus.none;
      _currentState.hasModifications = true;
      notifyListeners();
    }
  }

  void deletePair(int itemId) {
    _currentState.pairs.removeWhere((p) => p.sourceItem.id == itemId);
    _currentState.hasModifications = true;
    notifyListeners();
  }

  void addManualRow() {
    int maxId = 0;
    if (_currentState.pairs.isNotEmpty) maxId = _currentState.pairs.map((p) => p.sourceItem.id).reduce((curr, next) => curr > next ? curr : next);
    final newItem = ExtractedItem(id: maxId + 1, originalText: "Agregado Manual", fullName: "Nuevo Ítem", quantity: 1, unit: "und");
    _currentState.pairs.add(MatchPair(sourceItem: newItem, status: MatchStatus.none));
    _currentState.hasModifications = true;
    notifyListeners();
  }

  Future<int?> saveQuotation(
    String status, {
      String? manualClientName, String? manualClientPhone, String? manualClientDni, String? manualClientAddress, String? manualClientEmail, String? manualClientNotes,
      bool updateClientData = true, String? institutionName, String? gradeLevel, String? type, bool isClientRole = false, 
      String? quoteTitle, String? quoteNotes,
    }
  ) async {
    final activeState = _currentState;
    final activeNegocioId = _negocioId;
    if (activeNegocioId == null || _usuarioId == null) return null;
    
    activeState.isSaving = true;
    notifyListeners();

    try {
      if (activeState.pairs.isEmpty) {
        activeState.errorMessage = "No se puede guardar una lista vacía";
        return null;
      }

      activeState.metadata ??= ExtractedMetadata();
      activeState.metadata!.institutionName = (institutionName != null && institutionName.trim().isNotEmpty) ? institutionName.trim() : null;
      activeState.metadata!.gradeLevel = (gradeLevel != null && gradeLevel.trim().isNotEmpty) ? gradeLevel.trim() : null;

      String? uploadedImageUrl;
      if (activeState.localImageFile != null) {
          uploadedImageUrl = await _service.uploadImageToBackend(activeState.localImageFile!);
      }

      final List<Map<String, dynamic>> validItems = [];

      for (var p in activeState.pairs.where((p) => p.selectedProduct != null)) {
        var itemJson = p.toQuotationItemJson(); 
        if (itemJson != null) {
          itemJson['original_text'] = p.sourceItem.originalText;
          validItems.add(itemJson);
        }
      }

      if (validItems.isEmpty) {
        activeState.errorMessage = "Selecciona al menos un producto para guardar.";
        return null;
      }

      int? finalClientId = (activeState.selectedClient?.id == 0) ? null : activeState.selectedClient?.id;
      String rawClientName = activeState.selectedClient?.fullName ?? manualClientName?.trim() ?? "";

      if (!isClientRole && updateClientData && rawClientName.isNotEmpty) {
        final clientData = {
          'nombre_completo': rawClientName, 'telefono': manualClientPhone?.replaceAll(" ", "") ?? "",
          'dni_ruc': manualClientDni?.trim(), 'direccion': manualClientAddress?.trim(),
          'correo': manualClientEmail?.trim(), 'notas': manualClientNotes?.trim()
        };
        
        try {
          if (activeState.selectedClient != null && activeState.selectedClient!.id != 0) {
            await _clientService.updateClient(activeState.selectedClient!.id, clientData);
          } else {
            final newClient = await _clientService.createClient(clientData, activeNegocioId, _usuarioId!);
            finalClientId = newClient.id; 
          }
        } catch (e) {
          debugPrint("Error guardando cliente CRM: $e");
        }
      }

      String finalQuoteName = quoteTitle?.trim() ?? "";
      if (finalQuoteName.isEmpty) {
        int? count;
        if (finalClientId != null) {
          try {
            final list = await _clientService.getPendingQuotations(finalClientId);
            count = list.length + 1;
          } catch (_) {}
        }

        finalQuoteName = QuotationNamingEngine.generateTitle(
          selectedClient: activeState.selectedClient,
          typedClientName: rawClientName,
          schoolName: institutionName,
          gradeLevel: gradeLevel,
          quotationType: type ?? 'ai_scan',
          clientListIndex: count,
          isClientRole: isClientRole,
          clientUserName: manualClientName,
        );
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
        "institution_name": activeState.metadata?.institutionName,
        "grade_level": activeState.metadata?.gradeLevel,
        "notas": quoteNotes?.trim(),
        "total_amount": double.parse(finalAmount.toStringAsFixed(2)),
        "total_savings": double.parse(finalSavings.toStringAsFixed(2)),
        "status": status, 
        "type": type ?? "ai_scan",
        "source_image_url": uploadedImageUrl, 
        "items": validItems,
        "original_text_dump": activeState.fullExtractedText 
      };

      final newId = await _service.saveQuotation(quotationPayload, activeNegocioId, _usuarioId!);
      return newId;

    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      activeState.isSaving = false;
      notifyListeners();
    }
  }
}