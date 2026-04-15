import 'package:flutter/material.dart';
import '../../../models/inventory_wrapper.dart';
import '../models/matching_model.dart';
import '../models/smart_quotation_model.dart'; 
import '../../../../providers/inventory_provider.dart';

class QuickSaleProvider with ChangeNotifier {
  
  // --- ESTADO DEL CARRITO ---
  final List<MatchedProduct> _cart = [];
  final Map<int, int> _quantities = {}; 
  final Map<int, double> _overridePrices = {}; 

  // --- DATOS DEL CLIENTE Y VENTA ---
  int? _clientId; 
  String? _clientName;
  String? _clientPhone;
  String? _clientNote; 
  String? _saleNote;   
  double _clientSaldo = 0.0; 

  List<MatchedProduct> get cartItems => _cart;
  int? get clientId => _clientId;
  String? get clientName => _clientName;
  String? get clientPhone => _clientPhone;
  String? get clientNote => _clientNote;
  String? get saleNote => _saleNote;
  double get clientSaldo => _clientSaldo;

  bool get isEmpty => _cart.isEmpty && _clientId == null && (_clientName == null || _clientName!.isEmpty) && (_saleNote == null || _saleNote!.isEmpty);

  // --- CÁLCULOS MATEMÁTICOS ---
  double get totalOriginalPrice {
    double total = 0;
    for (var item in _cart) {
      final qty = _quantities[item.presentationId] ?? 1;
      total += item.price * qty; 
    }
    return total;
  }

  double get totalToPay {
    double total = 0;
    for (var item in _cart) {
      final qty = _quantities[item.presentationId] ?? 1;
      final effectivePrice = _overridePrices[item.presentationId] ?? item.offerPrice ?? item.price;
      total += effectivePrice * qty;
    }
    return total;
  }

  double get totalSavings {
    final diff = totalOriginalPrice - totalToPay;
    return diff > 0 ? diff : 0.0;
  }

  int getQuantity(int presentationId) => _quantities[presentationId] ?? 1;
  
  double getEffectivePrice(int presentationId) {
    final item = _cart.firstWhere((p) => p.presentationId == presentationId);
    return _overridePrices[presentationId] ?? item.offerPrice ?? item.price;
  }

  // --- FUNCIONES DE CARRITO Y CLIENTE ---
  void setClientInfo({int? id, String? name, String? phone, String? clientNote, String? saleNote, double? saldo}) {
    _clientId = id;
    _clientName = name;
    _clientPhone = phone;
    if (clientNote != null) _clientNote = clientNote;
    if (saleNote != null) _saleNote = saleNote;
    if (saldo != null) _clientSaldo = saldo;
    notifyListeners();
  }

  void clearSaleNote() {
    _saleNote = null;
    notifyListeners();
  }

  // 🔥 Retorna un String si hay error, o null si fue exitoso
  String? addToCart(InventoryWrapper itemWrapper) {
    final presId = itemWrapper.presentation.id!;

    // Bloqueo de Stock amigable
    if (itemWrapper.isOutOfStock) {
      return "El producto '${itemWrapper.displayNameDetail}' se encuentra agotado.";
    }

    if (_cart.any((p) => p.presentationId == presId)) {
      return updateQuantity(presId, (_quantities[presId] ?? 1) + 1, itemWrapper.presentation.stockActual);
    }

    final matched = MatchedProduct(
      productId: itemWrapper.product.id,
      presentationId: presId,
      fullName: "${itemWrapper.product.nombre} ${itemWrapper.presentation.nombreEspecifico ?? ''}".trim(),
      productName: itemWrapper.product.nombre,
      specificName: itemWrapper.presentation.nombreEspecifico,
      brand: itemWrapper.product.marcaId?.toString(), 
      price: itemWrapper.presentation.precioVentaFinal, 
      offerPrice: (itemWrapper.presentation.precioOferta != null && itemWrapper.presentation.precioOferta! > 0) ? itemWrapper.presentation.precioOferta : null,
      stock: itemWrapper.presentation.stockActual,
      imageUrl: itemWrapper.presentation.imagenUrl ?? itemWrapper.product.imagenUrl,
      unit: itemWrapper.presentation.unidadVenta ?? "Unidad", 
      conversionFactor: itemWrapper.presentation.unidadesPorVenta, 
    );

    _cart.add(matched);
    _quantities[presId] = 1;
    notifyListeners();
    return null; // Sin errores
  }

  // 🔥 Retorna un String si hay error, o null si fue exitoso
  String? updateItemFromModal(MatchedProduct product, int newQty, double? newOverridePrice) {
    final index = _cart.indexWhere((p) => p.presentationId == product.presentationId);
    if (index != -1) {
      if (newQty > product.stock) {
        return "Solo hay ${product.stock} unidades disponibles en stock.";
      }

      _cart[index] = product; 
      _quantities[product.presentationId] = newQty;
      if (newOverridePrice != null) {
        _overridePrices[product.presentationId] = newOverridePrice;
      } else {
        _overridePrices.remove(product.presentationId);
      }
      notifyListeners();
    }
    return null;
  }

  // 🔥 Retorna un String si hay error, o null si fue exitoso
  String? updateQuantity(int presentationId, int newQty, int maxStock) {
    if (newQty <= 0) {
      removeItem(presentationId);
      return null;
    } else if (newQty > maxStock) {
      return "Solo dispones de $maxStock unidades en stock.";
    } else {
      _quantities[presentationId] = newQty;
      notifyListeners();
      return null;
    }
  }

  void removeItem(int presentationId) {
    _cart.removeWhere((p) => p.presentationId == presentationId);
    _quantities.remove(presentationId);
    _overridePrices.remove(presentationId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _quantities.clear();
    _overridePrices.clear();
    _clientId = null;
    _clientName = null;
    _clientPhone = null;
    _clientNote = null;
    _saleNote = null;
    _clientSaldo = 0.0;
    notifyListeners();
  }

  void reorderCart(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _cart.removeAt(oldIndex);
    _cart.insert(newIndex, item);
    notifyListeners();
  }

  SmartQuotationModel generateDummyQuotation() {
    final items = _cart.map((p) {
      final qty = _quantities[p.presentationId] ?? 1;
      final effPrice = _overridePrices[p.presentationId] ?? p.offerPrice ?? p.price;
      
      return QuotationItem(
        id: p.presentationId, 
        productId: p.productId,
        presentationId: p.presentationId,
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
      negocioId: 0, 
      creadoPorUsuarioId: 0, 
      clientId: null,
      clientName: _clientName ?? "Cliente Rápido", 
      institutionName: "Venta al Paso", 
      gradeLevel: null,
      totalAmount: totalToPay,
      totalSavings: totalSavings,
      status: "SOLD",
      type: "pos_rapido",
      isTemplate: false,
      sourceImageUrl: null,
      originalTextDump: _saleNote, 
      createdAt: DateTime.now().toIso8601String(),
      itemCount: items.length,
      items: items,
    );
  }

  Future<Map<String, List<String>>> restoreCartFromHistory(
    List<dynamic> historicalItems, 
    InventoryProvider invProv,
    {bool clearPrevious = true}
  ) async {
    List<String> notFound = [];
    List<String> outOfStock = [];
    
    if (clearPrevious) clearCart();

    for (var item in historicalItems) {
      int? prodId = item['product_id'];
      int? presId = item['presentation_id'];
      int requestedQty = item['quantity'] ?? 1;
      
      String fallbackName = item['product_name'] ?? 'Ítem desconocido';

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
            brand: prod.marcaId?.toString(), 
            price: pres.precioVentaFinal, 
            offerPrice: (pres.precioOferta != null && pres.precioOferta! > 0) ? pres.precioOferta : null,
            stock: pres.stockActual, imageUrl: pres.imagenUrl ?? prod.imagenUrl,
            unit: pres.unidadVenta ?? "Unidad", 
            conversionFactor: pres.unidadesPorVenta, 
          );
          
          if (_cart.any((p) => p.presentationId == pres.id)) {
            int currentQty = _quantities[pres.id!] ?? 0;
            int potentialQty = currentQty + finalQty;
            _quantities[pres.id!] = potentialQty > pres.stockActual ? pres.stockActual : potentialQty;
          } else {
            _cart.add(matched);
            _quantities[pres.id!] = finalQty;
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