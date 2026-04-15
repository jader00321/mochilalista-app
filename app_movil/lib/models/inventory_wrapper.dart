// app/models/inventory_wrapper.dart
import 'product_model.dart';

class InventoryWrapper {
  final Product product; 
  final ProductPresentation presentation; 

  InventoryWrapper({
    required this.product,
    required this.presentation,
  });

  factory InventoryWrapper.fromJson(Map<String, dynamic> json) {
    return InventoryWrapper(
      product: Product.fromJson(json['product']),
      presentation: ProductPresentation.fromJson(json['presentation']),
    );
  }

  String get displayName {
    String unidad = presentation.unidadVenta ?? "Unidad";
    return "${product.nombre} - $unidad";
  }
  
  String get displayNameDetail {
    String name = product.nombre;
    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty) {
      name += " ${presentation.nombreEspecifico}";
    }
    return name;
  }
  
  double get effectivePrice => (presentation.precioOferta != null && presentation.precioOferta! > 0) 
      ? presentation.precioOferta! 
      : presentation.precioVentaFinal;
      
  bool get hasOffer => presentation.precioOferta != null && presentation.precioOferta! > 0;

  String get marginProfitInfo {
    if (presentation.factorGananciaVenta != null) {
      int porcentaje = ((presentation.factorGananciaVenta! - 1.0) * 100).round();
      return "+$porcentaje% Margen";
    }
    return "Margen No Definido";
  }

  // 🔥 CONTROL DE STOCK VISUAL: Ahora funcionará sin errores
  bool get isOutOfStock => presentation.stockActual <= 0;
  
  // Se considera stock bajo si es menor o igual a la alerta (por defecto 5)
  bool get isLowStock => presentation.stockActual > 0 && 
                         presentation.stockActual <= (presentation.stockAlerta ?? 5);
}