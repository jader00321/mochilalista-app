import 'package:flutter/foundation.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/features/promotions/models/campaign_model.dart';
import 'package:app_movil/features/promotions/models/promotion_rule_model.dart';
import 'package:app_movil/features/promotions/repositories/promotion_repository.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/utils/app_logger.dart';

class PromotionProvider with ChangeNotifier {
  final PromotionRepository _repository = PromotionRepository();
  InventoryProvider? _inventoryProvider;
  int _negocioId = 0;

  List<CampaignModel> _campaigns = [];
  List<BundleModel> _bundles = [];
  final Map<int, List<BundleItemModel>> _bundleItemsCache = {}; 
  final List<PromotionRuleModel> _promotionRules = [];

  List<CampaignModel> get campaigns => _campaigns;
  List<BundleModel> get bundles => _bundles;
  List<PromotionRuleModel> get promotionRules => _promotionRules;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void refreshUI() {
    notifyListeners();
  }

  void updateContext(int negocioId, InventoryProvider inventoryProvider) {
    _inventoryProvider = inventoryProvider;
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      if (_negocioId > 0) {
        loadPromotions(_negocioId);
      }
    }
  }

  Future<void> loadPromotions(int negocioId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final campRows = await _repository.getCampaigns(negocioId);
      _campaigns = campRows.map((e) => CampaignModel.fromJson(e)).toList();

      final bunRows = await _repository.getBundles(negocioId);
      _bundles = bunRows.map((e) => BundleModel.fromJson(e)).toList();

      _bundleItemsCache.clear();
      for (var bundle in _bundles) {
        final itemsRows = await _repository.getBundleItems(bundle.id);
        _bundleItemsCache[bundle.id] = itemsRows.map((e) => BundleItemModel.fromJson(e)).toList();
      }

      _promotionRules.clear();
      for (var campaign in _campaigns) {
        final rulesRows = await _repository.getPromotionRules(campaign.id);
        _promotionRules.addAll(rulesRows.map((e) => PromotionRuleModel.fromJson(e)).toList());
      }
      
      // Limpiar items de paquetes que ya no existen en inventario
      await cleanOrphanedBundleItems();
    } catch (e, stack) {
      AppLogger.error('PromotionProvider.loadPromotions', e, stack);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cleanOrphanedBundleItems() async {
    if (_inventoryProvider == null || _inventoryProvider!.items.isEmpty) return;
    bool needsReload = false;
    
    for (var bundleId in _bundleItemsCache.keys) {
      final items = _bundleItemsCache[bundleId]!;
      for (var item in items) {
        final exists = _inventoryProvider!.items.any((p) => p.presentation.id == item.presentacionId);
        if (!exists) {
          try {
            await _repository.deleteBundleItem(item.id);
            needsReload = true;
          } catch(e) {
            AppLogger.error('PromotionProvider.cleanOrphanedBundleItems', e);
          }
        }
      }
    }
    
    if (needsReload && _negocioId > 0) {
      // Reload silently to update the cache
      final bunRows = await _repository.getBundles(_negocioId);
      _bundles = bunRows.map((e) => BundleModel.fromJson(e)).toList();

      _bundleItemsCache.clear();
      for (var bundle in _bundles) {
        final itemsRows = await _repository.getBundleItems(bundle.id);
        _bundleItemsCache[bundle.id] = itemsRows.map((e) => BundleItemModel.fromJson(e)).toList();
      }
    }
  }

  // ================= CRUD BUNDLES =================
  Future<void> saveBundle(BundleModel bundle, List<BundleItemModel> items) async {
    try {
      int bundleId = bundle.id;
      if (bundleId == 0) {
        bundleId = await _repository.insertBundle(bundle.toJson()..remove('id'));
      } else {
        await _repository.updateBundle(bundleId, bundle.toJson());
        await _repository.deleteBundleItems(bundleId); // Limpiar para recrear
      }

      for (var item in items) {
        var itemJson = item.toJson()..remove('id');
        itemJson['paquete_id'] = bundleId;
        await _repository.insertBundleItem(itemJson);
      }
      await loadPromotions(_negocioId);
    } catch (e, stack) {
      AppLogger.error('PromotionProvider.saveBundle', e, stack);
      rethrow;
    }
  }

  Future<void> deleteBundle(int bundleId) async {
    try {
      await _repository.deleteBundleItems(bundleId);
      await _repository.deleteBundle(bundleId);
      await loadPromotions(_negocioId);
    } catch (e, stack) {
      AppLogger.error('PromotionProvider.deleteBundle', e, stack);
      rethrow;
    }
  }

  // ================= LÓGICA DE BUNDLES (CUELLO DE BOTELLA) =================
  List<BundleItemModel> getItemsForBundle(int bundleId) {
    return _bundleItemsCache[bundleId] ?? [];
  }

  /// Calcula cuántos paquetes se pueden armar basándose en el stock de los productos físicos.
  int calculateBundleMaxStock(int bundleId) {
    if (_inventoryProvider == null) return 0;
    
    final items = getItemsForBundle(bundleId);
    if (items.isEmpty) return 0;

    int maxBundles = 999999;
    for (var item in items) {
      try {
        final productWrap = _inventoryProvider!.items.where(
          (p) => p.presentation.id == item.presentacionId,
        ).firstOrNull;
        
        if (productWrap == null) return 0;
        
        final currentStock = productWrap.presentation.stockActual;
        final requiredQty = item.cantidadRequerida;

        if (requiredQty <= 0) continue;

        int possibleForThisItem = (currentStock / requiredQty).floor();
        if (possibleForThisItem < maxBundles) {
          maxBundles = possibleForThisItem;
        }
      } catch (e) {
        // Producto no encontrado en inventario (fue borrado).
        // No se puede armar el paquete.
        return 0;
      }
    }

    return maxBundles == 999999 ? 0 : maxBundles;
  }

  /// Verifica si una presentación pertenece a algún paquete activo
  List<BundleModel> getBundlesForPresentation(int presentacionId) {
    List<BundleModel> result = [];
    for (var bundle in _bundles) {
      if (!bundle.activo) continue;
      final items = getItemsForBundle(bundle.id);
      if (items.any((item) => item.presentacionId == presentacionId)) {
        result.add(bundle);
      }
    }
    return result;
  }

  InventoryProvider? get inventoryProvider => _inventoryProvider;

  /// Calcula el costo total de los productos físicos que componen un paquete
  double? calculateBundleCost(int bundleId) {
    if (_inventoryProvider == null) return null;
    final items = getItemsForBundle(bundleId);
    if (items.isEmpty) return null;

    double totalCost = 0.0;
    bool hasValidCost = false;
    for (var item in items) {
      final productWrap = _inventoryProvider!.items.where(
        (p) => p.presentation.id == item.presentacionId,
      ).firstOrNull;
      if (productWrap != null) {
        final cost = productWrap.presentation.costoPresentacionFinal;
        if (cost > 0) {
          totalCost += cost * item.cantidadRequerida;
          hasValidCost = true;
        } else if (productWrap.presentation.factorGananciaVenta != null &&
            productWrap.presentation.factorGananciaVenta! > 0) {
          totalCost += (productWrap.presentation.precioVentaFinal / productWrap.presentation.factorGananciaVenta!) * item.cantidadRequerida;
          hasValidCost = true;
        }
      }
    }
    return (hasValidCost && totalCost > 0) ? totalCost : null;
  }
}
