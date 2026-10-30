import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart'; 
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

class QuickSaleState {
  final List<MatchedProduct> cart = [];
  final Map<int, int> quantities = {}; 
  final Map<int, double> overridePrices = {}; 

  ClientModel? selectedClient;
  int? clientId; 
  String? clientName;
  String? clientPhone;
  String? clientNote; 
  String? saleNote;   
  double clientSaldo = 0.0; 
}

class QuickSaleProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;
  
  bool _hideProfits = false;
  bool get hideProfits => _hideProfits;

  QuickSaleProvider() {
    _loadPrivacyPreference();
  }

  Future<void> _loadPrivacyPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hideProfits = prefs.getBool('commercial_hide_profits') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleHideProfits() async {
    _hideProfits = !_hideProfits;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('commercial_hide_profits', _hideProfits);
    } catch (_) {}
  }

  final Map<int, QuickSaleState> _states = {};

  QuickSaleState get _currentState {
    final key = _negocioId ?? 0;
    return _states.putIfAbsent(key, () => QuickSaleState());
  }

  List<MatchedProduct> get cartItems => _currentState.cart;
  ClientModel? get selectedClient => _currentState.selectedClient;
  int? get clientId => _currentState.clientId;
  String? get clientName => _currentState.clientName;
  String? get clientPhone => _currentState.clientPhone;
  String? get clientNote => _currentState.clientNote;
  String? get saleNote => _currentState.saleNote;
  double get clientSaldo => _currentState.clientSaldo;

  bool get isEmpty => _currentState.cart.isEmpty && _currentState.clientId == null && (_currentState.clientName == null || _currentState.clientName!.isEmpty) && (_currentState.saleNote == null || _currentState.saleNote!.isEmpty);

  double get totalOriginalPrice {
    double total = 0;
    for (var item in _currentState.cart) {
      final qty = _currentState.quantities[item.presentationId] ?? 1;
      total += item.price * qty; 
    }
    return total;
  }

  double get totalToPay {
    double total = 0;
    for (var item in _currentState.cart) {
      final qty = _currentState.quantities[item.presentationId] ?? 1;
      final effectivePrice = _currentState.overridePrices[item.presentationId] ?? item.offerPrice ?? item.price;
      total += effectivePrice * qty;
    }
    return total;
  }

  double get totalSavings {
    final diff = totalOriginalPrice - totalToPay;
    return diff > 0 ? diff : 0.0;
  }

  // 🔧 TAREA 4.4.3: Ganancia estimada del carrito actual
  double get estimatedCartProfit {
    double profit = 0;
    for (var item in _currentState.cart) {
      final qty = _currentState.quantities[item.presentationId] ?? 1;
      final effectivePrice = _currentState.overridePrices[item.presentationId] ?? item.offerPrice ?? item.price;
      if (item.cost != null && item.cost! > 0) {
        profit += (effectivePrice - item.cost!) * qty;
      }
    }
    return profit > 0 ? profit : 0.0;
  }

  int getQuantity(int presentationId) {
    if (!_currentState.cart.any((p) => p.presentationId == presentationId)) return 0;
    return _currentState.quantities[presentationId] ?? 1;
  }
  
  double getEffectivePrice(int presentationId) {
    final item = _currentState.cart.firstWhere((p) => p.presentationId == presentationId);
    return _currentState.overridePrices[presentationId] ?? item.offerPrice ?? item.price;
  }

  void updateContext(int? negocioId, int? usuarioId) {
    if (_negocioId != negocioId || _usuarioId != usuarioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      // Ya no borramos el carrito, simplemente al cambiar _negocioId el getter apuntará a otro estado
      Future.microtask(() {
        notifyListeners();
      });
    }
  }

  void setClientInfo({
    ClientModel? client,
    int? id,
    String? name,
    String? phone,
    String? clientNote,
    String? saleNote,
    double? saldo,
  }) {
    if (client != null) {
      _currentState.selectedClient = client;
      _currentState.clientId = client.id == 0 ? null : client.id;
      _currentState.clientName = client.fullName;
      _currentState.clientPhone = client.phone;
      _currentState.clientNote = client.notes;
      _currentState.clientSaldo = client.saldoAFavor;
    } else {
      if (id == null && name == null && phone == null) {
        _currentState.selectedClient = null;
      }
      _currentState.clientId = id;
      _currentState.clientName = name;
      _currentState.clientPhone = phone;
      if (clientNote != null) _currentState.clientNote = clientNote;
      if (saldo != null) _currentState.clientSaldo = saldo;
    }
    if (saleNote != null) _currentState.saleNote = saleNote;
    notifyListeners();
  }

  void updateSelectedClientData(ClientModel client) {
    _currentState.selectedClient = client;
    _currentState.clientId = client.id == 0 ? null : client.id;
    _currentState.clientName = client.fullName;
    _currentState.clientPhone = client.phone;
    _currentState.clientNote = client.notes;
    _currentState.clientSaldo = client.saldoAFavor;
    notifyListeners();
  }

  void clearSaleNote() {
    _currentState.saleNote = null;
    notifyListeners();
  }

  /// 🔗 Valida la demanda acumulada en vivo para ítems que comparten pool de stock.
  /// Cumple estrictamente con la Regla 2: Aísla variantes compartidas (item.productId == prodId && item.usaStockCompartido)
  /// de variantes independientes en modo MIXTO o INDEPENDIENTE.
  /// 🔗 Calcula el stock base restante del pool compartido descontando la demanda de todas las variantes del carrito
  int getRemainingPoolStock(int productId, int initialPool) {
    if (productId <= 0) return initialPool;
    int currentDemand = 0;
    for (final item in _currentState.cart) {
      if (item.productId == productId && item.usaStockCompartido) {
        final qty = _currentState.quantities[item.presentationId] ?? 0;
        final f = item.conversionFactor > 0 ? item.conversionFactor : 1;
        currentDemand += qty * f;
      }
    }
    final remaining = initialPool - currentDemand;
    return remaining > 0 ? remaining : 0;
  }

  /// 🔗 Calcula cuántas unidades vendibles quedan disponibles para agregar al carrito en vivo
  int getRemainingVendibleStock(InventoryWrapper item) {
    if (item.hasSharedStock) {
      final pool = item.product.stockCompartido > 0
          ? item.product.stockCompartido
          : item.presentation.stockActual;
      final remainingPool = getRemainingPoolStock(item.product.id, pool);
      final factor = item.presentation.unidadesPorVenta > 0
          ? item.presentation.unidadesPorVenta
          : 1;
      final physical = remainingPool ~/ factor;
      if (item.presentation.cupoMaximoVariante != null) {
        final inCart = _currentState.quantities[item.presentation.id] ?? 0;
        final effectiveQuota = item.presentation.cupoMaximoVariante! - inCart;
        final quotaRemaining = effectiveQuota > 0 ? effectiveQuota : 0;
        return physical < quotaRemaining ? physical : quotaRemaining;
      }
      return physical;
    } else {
      final inCart = _currentState.quantities[item.presentation.id] ?? 0;
      final available = item.displayStock - inCart;
      return available > 0 ? available : 0;
    }
  }

  /// 🔗 Calcula cuántas unidades vendibles quedan de una presentación específica (usado en modales de detalle)
  int getRemainingAvailableForPresentation({
    required int productId,
    required ProductPresentation presentation,
    int? sharedStockPool,
    int? excludePresentationId,
  }) {
    final factor = presentation.unidadesPorVenta > 0 ? presentation.unidadesPorVenta : 1;
    if (presentation.usaStockCompartido) {
      int pool = sharedStockPool ?? presentation.stockActual;
      int currentDemand = 0;
      for (final item in _currentState.cart) {
        if (item.productId == productId &&
            item.usaStockCompartido &&
            item.presentationId != excludePresentationId) {
          final qty = _currentState.quantities[item.presentationId] ?? 0;
          final f = item.conversionFactor > 0 ? item.conversionFactor : 1;
          currentDemand += qty * f;
        }
      }
      final remainingPool = pool - currentDemand;
      final physical = remainingPool > 0 ? (remainingPool ~/ factor) : 0;
      if (presentation.cupoMaximoVariante != null) {
        int inCart = 0;
        if (presentation.id != excludePresentationId) {
          inCart = _currentState.quantities[presentation.id] ?? 0;
        }
        final quotaRemaining = (presentation.cupoMaximoVariante! - inCart).clamp(0, presentation.cupoMaximoVariante!);
        return physical < quotaRemaining ? physical : quotaRemaining;
      }
      return physical;
    } else {
      int inCart = 0;
      if (presentation.id != excludePresentationId) {
        inCart = _currentState.quantities[presentation.id] ?? 0;
      }
      final available = (presentation.stockActual ~/ factor) - inCart;
      return available > 0 ? available : 0;
    }
  }

  String? _validateSharedStockDemand({
    required int productId,
    required int presentationId,
    required bool usaStockCompartido,
    required int sharedStockPool,
    required int factor,
    required int targetQty,
    required String unitName,
    int? cupoMaximoVariante,
  }) {
    if (!usaStockCompartido || productId <= 0) return null;

    if (cupoMaximoVariante != null && targetQty > cupoMaximoVariante) {
      return "El cupo asignado para esta variante es de $cupoMaximoVariante $unitName.";
    }

    int currentDemand = 0;
    for (final item in _currentState.cart) {
      if (item.productId == productId && item.usaStockCompartido && item.presentationId != presentationId) {
        final qty = _currentState.quantities[item.presentationId] ?? 0;
        final f = item.conversionFactor > 0 ? item.conversionFactor : 1;
        currentDemand += qty * f;
      }
    }

    final int safeFactor = factor > 0 ? factor : 1;
    final int newDemandForThisItem = targetQty * safeFactor;
    final int totalDemand = currentDemand + newDemandForThisItem;

    if (totalDemand > sharedStockPool) {
      final int remainingUnits = sharedStockPool - currentDemand;
      final int maxAvailableForThis = remainingUnits > 0 ? (remainingUnits ~/ safeFactor) : 0;
      return "Stock compartido insuficiente. Quedan $remainingUnits und. base disponibles (= $maxAvailableForThis $unitName).";
    }

    return null;
  }

  String? addToCart(InventoryWrapper itemWrapper) {
    final presId = itemWrapper.presentation.id!;

    if (itemWrapper.isOutOfStock) {
      return "El producto '${itemWrapper.displayNameDetail}' se encuentra agotado.";
    }

    final bool isShared = itemWrapper.hasSharedStock;
    final int pool = itemWrapper.product.stockCompartido > 0
        ? itemWrapper.product.stockCompartido
        : itemWrapper.presentation.stockActual;

    if (_currentState.cart.any((p) => p.presentationId == presId)) {
      return updateQuantity(presId, (_currentState.quantities[presId] ?? 1) + 1, itemWrapper.displayStockForValidation);
    }

    // Validar demanda compartida inicial para cantidad = 1
    if (isShared) {
      final sharedWarning = _validateSharedStockDemand(
        productId: itemWrapper.product.id,
        presentationId: presId,
        usaStockCompartido: isShared,
        sharedStockPool: pool,
        factor: itemWrapper.presentation.unidadesPorVenta,
        targetQty: 1,
        unitName: itemWrapper.presentation.unidadVenta ?? "Unidad",
        cupoMaximoVariante: itemWrapper.presentation.cupoMaximoVariante,
      );
      if (sharedWarning != null) return sharedWarning;
    }

    // 🔧 Costo de presentación para cálculo de margen en tiempo real
    final double presCost = itemWrapper.presentation.costoPresentacionFinal;
    final double? calculatedCost = presCost > 0
        ? presCost
        : (itemWrapper.presentation.factorGananciaVenta != null && itemWrapper.presentation.factorGananciaVenta! > 0
            ? itemWrapper.presentation.precioVentaFinal / itemWrapper.presentation.factorGananciaVenta!
            : null);

    final matched = MatchedProduct(
      productId: itemWrapper.product.id,
      presentationId: presId,
      fullName: "${itemWrapper.product.nombre} ${itemWrapper.presentation.nombreEspecifico ?? ''}".trim(),
      productName: itemWrapper.product.nombre,
      specificName: itemWrapper.presentation.nombreEspecifico,
      brand: itemWrapper.product.marcaNombre,
      price: itemWrapper.presentation.precioVentaFinal, 
      offerPrice: itemWrapper.hasOffer ? itemWrapper.effectivePrice : null,
      stock: itemWrapper.displayStockForValidation,
      imageUrl: itemWrapper.presentation.imagenUrl ?? itemWrapper.product.imagenUrl,
      unit: itemWrapper.presentation.unidadVenta ?? "Unidad", 
      conversionFactor: itemWrapper.presentation.unidadesPorVenta,
      cost: calculatedCost,
      usaStockCompartido: isShared,
      sharedStockPool: pool,
      cupoMaximoVariante: itemWrapper.presentation.cupoMaximoVariante,
    );

    _currentState.cart.add(matched);
    _currentState.quantities[presId] = 1;
    notifyListeners();
    return null; 
  }

  String? addBundleToCart(BundleModel bundle, int maxStock) {
    if (maxStock <= 0) {
      return "El paquete '${bundle.nombrePaquete}' no tiene stock suficiente (uno o más componentes agotados).";
    }

    final fakePresId = -(bundle.id); 

    if (_currentState.cart.any((p) => p.presentationId == fakePresId)) {
      return updateQuantity(fakePresId, (_currentState.quantities[fakePresId] ?? 1) + 1, maxStock);
    }

    final matched = MatchedProduct(
      productId: 0,
      presentationId: fakePresId,
      fullName: bundle.nombrePaquete,
      productName: bundle.nombrePaquete,
      specificName: bundle.descripcion != null && bundle.descripcion!.isNotEmpty ? bundle.descripcion : "Paquete",
      brand: "OFERTA",
      price: bundle.precioVentaTotal,
      stock: maxStock,
      imageUrl: bundle.imagenUrl,
      unit: "Paquete",
      bundleId: bundle.id,
      cost: bundle.costoTotalCalculado,
    );

    _currentState.cart.add(matched);
    _currentState.quantities[fakePresId] = 1;
    notifyListeners();
    return null;
  }

  String? updateItemFromModal(int oldPresentationId, MatchedProduct product, int newQty, double? newOverridePrice) {
    final index = _currentState.cart.indexWhere((p) => p.presentationId == oldPresentationId);
    if (index != -1) {
      if (oldPresentationId != product.presentationId) {
        // Chequear si la nueva variante ya está presente en el carrito
        final existingTargetIndex = _currentState.cart.indexWhere((p) => p.presentationId == product.presentationId);
        if (existingTargetIndex != -1 && existingTargetIndex != index) {
          if (product.stock <= 0) {
            return "No hay unidades disponibles en stock para esta presentación.";
          }
          final existingQty = _currentState.quantities[product.presentationId] ?? 1;
          final maxStock = product.stock > 0 ? product.stock : 1;
          final combinedQty = (existingQty + newQty).clamp(1, maxStock);
          
          // Calcular el índice destino ajustado tras eliminar el ítem previo
          final targetIndex = existingTargetIndex > index ? existingTargetIndex - 1 : existingTargetIndex;

          // Remover el ítem viejo y sus propiedades huérfanas
          _currentState.cart.removeAt(index);
          _currentState.quantities.remove(oldPresentationId);
          _currentState.overridePrices.remove(oldPresentationId);
          
          // Actualizar el ítem existente fusionado con sus datos más recientes
          _currentState.cart[targetIndex] = product;
          _currentState.quantities[product.presentationId] = combinedQty;
          if (newOverridePrice != null) {
            _currentState.overridePrices[product.presentationId] = newOverridePrice;
          } else {
            _currentState.overridePrices.remove(product.presentationId);
          }
          notifyListeners();

          if (existingQty + newQty > maxStock) {
            return "Se fusionaron las presentaciones. Cantidad ajustada al stock máximo disponible ($maxStock).";
          }
          return null;
        }

        // Si no existía previamente, removemos el id anterior de las estructuras
        _currentState.quantities.remove(oldPresentationId);
        _currentState.overridePrices.remove(oldPresentationId);
      }

      if (product.usaStockCompartido) {
        final sharedWarning = _validateSharedStockDemand(
          productId: product.productId,
          presentationId: product.presentationId,
          usaStockCompartido: true,
          sharedStockPool: product.sharedStockPool,
          factor: product.conversionFactor,
          targetQty: newQty,
          unitName: product.unit,
          cupoMaximoVariante: product.cupoMaximoVariante,
        );
        if (sharedWarning != null) return sharedWarning;
      } else if (newQty > product.stock) {
        return "Solo hay ${product.stock} unidades disponibles en stock.";
      }

      _currentState.cart[index] = product; 
      _currentState.quantities[product.presentationId] = newQty;
      if (newOverridePrice != null) {
        _currentState.overridePrices[product.presentationId] = newOverridePrice;
      } else {
        _currentState.overridePrices.remove(product.presentationId);
      }
      notifyListeners();
    }
    return null;
  }

  /// 🔄 Sincroniza inmediatamente precio, oferta y stock de un ítem en el carrito en memoria (0ms)
  void syncItemPriceAndStock(
    int presentationId, {
    double? newPrice,
    double? newOfferPrice,
    bool clearOffer = false,
    int? newStock,
    int? newCupoMaximoVariante,
    bool clearCupo = false,
  }) {
    final index = _currentState.cart.indexWhere((p) => p.presentationId == presentationId);
    if (index != -1) {
      final current = _currentState.cart[index];
      final double updatedPrice = newPrice ?? current.price;
      final double? updatedOffer = clearOffer ? null : (newOfferPrice ?? current.offerPrice);
      final int? updatedCupo = clearCupo ? null : (newCupoMaximoVariante ?? current.cupoMaximoVariante);

      final updated = current.copyWith(
        price: updatedPrice,
        offerPrice: updatedOffer,
        clearOfferPrice: clearOffer,
        stock: newStock ?? current.stock,
        cupoMaximoVariante: updatedCupo,
        clearCupo: clearCupo,
      );
      _currentState.cart[index] = updated;

      // Si el carrito tenía un precio override previo que correspondía al precio anterior,
      // lo sincronizamos al nuevo precio efectivo para que el total refleje la edición de catálogo
      if (_currentState.overridePrices.containsKey(presentationId)) {
        final oldEffective = current.offerPrice ?? current.price;
        if ((_currentState.overridePrices[presentationId]! - oldEffective).abs() < 0.01) {
          _currentState.overridePrices[presentationId] = updatedOffer ?? updatedPrice;
        }
      }

      // Si la cantidad en el carrito supera el nuevo stock o cupo, ajustarla al máximo disponible
      final currentQty = _currentState.quantities[presentationId] ?? 1;
      final effectiveMax = updated.effectiveVendibleStock;
      if (effectiveMax > 0 && currentQty > effectiveMax) {
        _currentState.quantities[presentationId] = effectiveMax;
      } else if (newStock != null && newStock > 0 && currentQty > newStock) {
        _currentState.quantities[presentationId] = newStock;
      }
      notifyListeners();
    }
  }

  String? updateQuantity(int presentationId, int newQty, int maxStock) {
    if (newQty <= 0) {
      removeItem(presentationId);
      return null;
    }

    final itemIndex = _currentState.cart.indexWhere((p) => p.presentationId == presentationId);
    if (itemIndex != -1) {
      final item = _currentState.cart[itemIndex];
      if (item.usaStockCompartido) {
        final sharedWarning = _validateSharedStockDemand(
          productId: item.productId,
          presentationId: presentationId,
          usaStockCompartido: true,
          sharedStockPool: item.sharedStockPool,
          factor: item.conversionFactor,
          targetQty: newQty,
          unitName: item.unit,
          cupoMaximoVariante: item.cupoMaximoVariante,
        );
        if (sharedWarning != null) return sharedWarning;
      } else if (newQty > maxStock) {
        return "Solo dispones de $maxStock unidades en stock.";
      }
    } else if (newQty > maxStock) {
      return "Solo dispones de $maxStock unidades en stock.";
    }

    _currentState.quantities[presentationId] = newQty;
    notifyListeners();
    return null;
  }

  void removeItem(int presentationId) {
    _currentState.cart.removeWhere((p) => p.presentationId == presentationId);
    _currentState.quantities.remove(presentationId);
    _currentState.overridePrices.remove(presentationId);
    notifyListeners();
  }

  void clearCart() {
    _currentState.cart.clear();
    _currentState.quantities.clear();
    _currentState.overridePrices.clear();
    _currentState.clientId = null;
    _currentState.clientName = null;
    _currentState.clientPhone = null;
    _currentState.clientNote = null;
    _currentState.saleNote = null;
    _currentState.clientSaldo = 0.0;
    notifyListeners();
  }

  void reorderCart(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _currentState.cart.removeAt(oldIndex);
    _currentState.cart.insert(newIndex, item);
    notifyListeners();
  }

  SmartQuotationModel generateDummyQuotation() {
    final items = _currentState.cart.map((p) {
      final qty = _currentState.quantities[p.presentationId] ?? 1;
      final effPrice = _currentState.overridePrices[p.presentationId] ?? p.offerPrice ?? p.price;
      
      return QuotationItem(
        id: p.bundleId != null ? 0 : p.presentationId, 
        productId: p.productId,
        presentationId: p.bundleId != null ? null : p.presentationId,
        bundleId: p.bundleId,
        productName: p.productName,
        brandName: p.brand,
        specificName: p.specificName,
        salesUnit: p.unit,
        quantity: qty,
        unitPriceApplied: effPrice,
        originalUnitPrice: p.price,
        isAvailable: true,
        originalText: "Producto POS Rápido", 
        imageUrl: p.imageUrl,
      );
    }).toList();

    return SmartQuotationModel(
      id: DateTime.now().millisecondsSinceEpoch % 100000, 
      negocioId: _negocioId ?? 0, 
      creadoPorUsuarioId: _usuarioId ?? 0, 
      clientId: null,
      clientName: _currentState.clientName ?? "Cliente Rápido", 
      institutionName: "Venta al Paso", 
      gradeLevel: null,
      totalAmount: totalToPay,
      totalSavings: totalSavings,
      status: "SOLD",
      type: "pos_rapido",
      isTemplate: false,
      sourceImageUrl: null,
      originalTextDump: _currentState.saleNote, 
      createdAt: DateTime.now().toIso8601String(),
      itemCount: items.length,
      items: items,
    );
  }

  Future<Map<String, List<String>>> restoreCartFromHistory(
    List<dynamic> historicalItems, 
    InventoryProvider invProv,
    PromotionProvider promoProv,
    {bool clearPrevious = true}
  ) async {
    List<String> notFound = [];
    List<String> outOfStock = [];
    
    if (clearPrevious) clearCart();

    for (var item in historicalItems) {
      int requestedQty = item['quantity'] ?? 1;
      String fallbackName = item['product_name'] ?? 'Ítem desconocido';

      int? bundleId = item['bundle_id'];
      if (bundleId != null) {
        final bundle = promoProv.bundles.where((b) => b.id == bundleId).firstOrNull;
        if (bundle == null || !bundle.activo) {
          notFound.add(fallbackName);
          continue;
        }
        
        int maxStock = promoProv.calculateBundleMaxStock(bundle.id);
        if (maxStock <= 0) {
          outOfStock.add(fallbackName);
          continue;
        }

        int finalQty = requestedQty > maxStock ? maxStock : requestedQty;
        String? error = addBundleToCart(bundle, maxStock);
        if (error != null) {
          outOfStock.add(fallbackName);
        } else {
          // addBundleToCart adds 1 by default, update to correct quantity
          final fakePresId = -(bundle.id);
          _currentState.quantities[fakePresId] = finalQty;
        }
        continue;
      }

      int? prodId = item['product_id'];
      int? presId = item['presentation_id'];

      if (prodId == null || presId == null) {
        notFound.add(fallbackName);
        continue;
      }

      var prod = await invProv.fetchProductById(prodId);
      
      if (prod != null) {
        try {
          var pres = prod.presentaciones.firstWhere((p) => p.id == presId);
          if (pres.stockActual <= 0) {
            outOfStock.add(prod.nombre);
            continue;
          }

          int finalQty = requestedQty > pres.stockActual ? pres.stockActual : requestedQty;

          final matched = MatchedProduct(
            productId: prod.id, presentationId: pres.id!,
            fullName: "${prod.nombre} ${pres.nombreEspecifico ?? ''}".trim(),
            productName: prod.nombre, specificName: pres.nombreEspecifico,
            brand: prod.marcaNombre, 
            price: pres.precioVentaFinal, 
            offerPrice: (pres.precioOferta != null && pres.precioOferta! > 0) ? pres.precioOferta : null,
            stock: pres.stockActual, imageUrl: pres.imagenUrl ?? prod.imagenUrl,
            unit: pres.unidadVenta ?? "Unidad", 
            conversionFactor: pres.unidadesPorVenta, 
          );
          
          if (_currentState.cart.any((p) => p.presentationId == pres.id)) {
            int currentQty = _currentState.quantities[pres.id!] ?? 0;
            int potentialQty = currentQty + finalQty;
            _currentState.quantities[pres.id!] = potentialQty > pres.stockActual ? pres.stockActual : potentialQty;
          } else {
            _currentState.cart.add(matched);
            _currentState.quantities[pres.id!] = finalQty;
          }
          
        } catch(e) {
          notFound.add(prod.nombre);
        }
      } else {
        notFound.add('Producto eliminado ($fallbackName)');
      }
    }
    notifyListeners();
    return {'notFound': notFound, 'outOfStock': outOfStock};
  }
}