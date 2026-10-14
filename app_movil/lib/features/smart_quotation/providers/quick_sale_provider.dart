import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart'; 
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class QuickSaleState {
  final List<MatchedProduct> cart = [];
  final Map<int, int> quantities = {}; 
  final Map<int, double> overridePrices = {}; 

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

  int getQuantity(int presentationId) => _currentState.quantities[presentationId] ?? 1;
  
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

  void setClientInfo({int? id, String? name, String? phone, String? clientNote, String? saleNote, double? saldo}) {
    _currentState.clientId = id;
    _currentState.clientName = name;
    _currentState.clientPhone = phone;
    if (clientNote != null) _currentState.clientNote = clientNote;
    if (saleNote != null) _currentState.saleNote = saleNote;
    if (saldo != null) _currentState.clientSaldo = saldo;
    notifyListeners();
  }

  void clearSaleNote() {
    _currentState.saleNote = null;
    notifyListeners();
  }

  String? addToCart(InventoryWrapper itemWrapper) {
    final presId = itemWrapper.presentation.id!;

    if (itemWrapper.isOutOfStock) {
      return "El producto '${itemWrapper.displayNameDetail}' se encuentra agotado.";
    }

    if (_currentState.cart.any((p) => p.presentationId == presId)) {
      return updateQuantity(presId, (_currentState.quantities[presId] ?? 1) + 1, itemWrapper.displayStockForValidation);
    }

    // 🔧 TAREA 4.4.2: Costo de presentación para cálculo de margen en tiempo real
    final double? calculatedCost = itemWrapper.presentation.costoUnitarioCalculado != null
        ? itemWrapper.presentation.costoUnitarioCalculado! * itemWrapper.presentation.unidadesPorVenta
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
      offerPrice: (itemWrapper.presentation.precioOferta != null && itemWrapper.presentation.precioOferta! > 0) ? itemWrapper.presentation.precioOferta : null,
      stock: itemWrapper.displayStockForValidation,
      imageUrl: itemWrapper.presentation.imagenUrl ?? itemWrapper.product.imagenUrl,
      unit: itemWrapper.presentation.unidadVenta ?? "Unidad", 
      conversionFactor: itemWrapper.presentation.unidadesPorVenta,
      cost: calculatedCost,
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
    );

    _currentState.cart.add(matched);
    _currentState.quantities[fakePresId] = 1;
    notifyListeners();
    return null;
  }

  String? updateItemFromModal(int oldPresentationId, MatchedProduct product, int newQty, double? newOverridePrice) {
    final index = _currentState.cart.indexWhere((p) => p.presentationId == oldPresentationId);
    if (index != -1) {
      if (newQty > product.stock) {
        return "Solo hay ${product.stock} unidades disponibles en stock.";
      }

      if (oldPresentationId != product.presentationId) {
        _currentState.quantities.remove(oldPresentationId);
        _currentState.overridePrices.remove(oldPresentationId);
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

  String? updateQuantity(int presentationId, int newQty, int maxStock) {
    if (newQty <= 0) {
      removeItem(presentationId);
      return null;
    } else if (newQty > maxStock) {
      return "Solo dispones de $maxStock unidades en stock.";
    } else {
      _currentState.quantities[presentationId] = newQty;
      notifyListeners();
      return null;
    }
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