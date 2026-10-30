import 'package:app_movil/features/catalog/models/product_model.dart';

class InventoryWrapper {
  final Product product;
  final ProductPresentation presentation;

  InventoryWrapper({required this.product, required this.presentation});

  factory InventoryWrapper.fromJson(Map<String, dynamic> json) {
    return InventoryWrapper(
      product: Product.fromJson(json['product']),
      presentation: ProductPresentation.fromJson(json['presentation']),
    );
  }

  InventoryWrapper copyWith({
    Product? product,
    ProductPresentation? presentation,
  }) {
    return InventoryWrapper(
      product: product ?? this.product,
      presentation: presentation ?? this.presentation,
    );
  }

  String get displayName {
    String unidad = presentation.unidadVenta ?? "Unidad";
    return "${product.nombre} - $unidad";
  }

  String get displayNameDetail {
    String name = product.nombre;
    if (presentation.nombreEspecifico != null &&
        presentation.nombreEspecifico!.isNotEmpty) {
      name += " ${presentation.nombreEspecifico}";
    }
    return name;
  }

  double get effectivePrice => presentation.effectivePrice;
  double get precio => presentation.precioVentaFinal;
  double? get precioOferta => presentation.precioOferta;

  bool get hasOffer => presentation.hasOffer;

  int get discountPercentRounded => presentation.discountPercentRounded;
  int get discountPercentage => presentation.discountPercentRounded;

  String get marginProfitInfo {
    if (presentation.factorGananciaVenta != null) {
      int porcentaje = ((presentation.factorGananciaVenta! - 1.0) * 100)
          .round();
      return "+$porcentaje% Margen";
    }
    return "Margen No Definido";
  }

  bool get isOutOfStock => displayStock <= 0;

  bool get isLowStock =>
      displayStock > 0 &&
      displayStock <= (presentation.stockAlerta ?? 5);

  /// Indica si esta presentación específica usa stock compartido
  bool get usaStockCompartido => presentation.usaStockCompartido;

  /// Indica si el producto o la presentación tienen un pool de stock compartido
  bool get hasSharedStock =>
      product.isStockCompartido ||
      (product.isStockMixto && presentation.usaStockCompartido);

  /// Stock base efectivo para esta presentación (del pool compartido si aplica o su stock independiente)
  int get effectiveBaseStock {
    if (hasSharedStock && product.stockCompartido > 0) {
      return product.stockCompartido;
    }
    return presentation.stockActual;
  }

  /// Factor de conversión de la presentación (unidades por unidad de venta)
  int get factor => presentation.unidadesPorVenta > 0 ? presentation.unidadesPorVenta : 1;

  /// Stock real para validaciones de carrito (en unidades de venta)
  int get displayStockForValidation => displayStock;

  int get displayStock {
    int factor = presentation.unidadesPorVenta;
    if (factor <= 0) factor = 1;
    final int baseCalculated = effectiveBaseStock ~/ factor;
    if (presentation.usaStockCompartido &&
        presentation.cupoMaximoVariante != null &&
        presentation.cupoMaximoVariante! > 0) {
      return presentation.cupoMaximoVariante! < baseCalculated
          ? presentation.cupoMaximoVariante!
          : baseCalculated;
    }
    return baseCalculated;
  }

  int get stockRemainder {
    int factor = presentation.unidadesPorVenta;
    if (factor <= 1) return 0;
    return effectiveBaseStock % factor;
  }

  bool get hasLooseUnits => stockRemainder > 0;

  String get presentationFactorChip {
    final rawUnit = presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad";
    final factor = presentation.unidadesPorVenta;
    if (factor > 1) {
      return "${rawUnit.toUpperCase()} · x$factor";
    }
    return rawUnit.toUpperCase();
  }

  static String pluralize(String rawUnit, int qty) {
    final unit = rawUnit.trim().isEmpty ? 'Unidad' : rawUnit.trim();
    final lower = unit.toLowerCase();

    // Si ya viene en plural desde BD (ej. 'unidades', 'pares', 'cajas', 'docenas', 'paquetes', 'packs')
    final bool alreadyPlural = lower.endsWith('es') ||
        (lower.endsWith('s') && !lower.endsWith('is') && !lower.endsWith('us'));

    if (qty == 1) {
      if (alreadyPlural) {
        if (lower == 'unidades') return unit.substring(0, unit.length - 2);
        if (lower == 'pares') return unit.substring(0, unit.length - 2);
        if (lower == 'cajas') return unit.substring(0, unit.length - 1);
        if (lower == 'docenas') return unit.substring(0, unit.length - 1);
        if (lower == 'paquetes') return unit.substring(0, unit.length - 1);
        if (lower == 'packs') return unit.substring(0, unit.length - 1);
        if (lower == 'lápices') return "${unit.substring(0, unit.length - 3)}z";
        return unit;
      }
      return unit;
    }

    if (alreadyPlural) {
      return unit;
    }

    if (lower.endsWith('z')) {
      return "${unit.substring(0, unit.length - 1)}ces";
    }
    if (lower.endsWith('d') ||
        lower.endsWith('r') ||
        lower.endsWith('n') ||
        lower.endsWith('l') ||
        lower.endsWith('j')) {
      return "${unit}es";
    }
    return "${unit}s";
  }

  String get displayStockText {
    if (displayStock <= 0) return "Agotado";
    String unidad = presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad";
    final pluralized = pluralize(unidad, displayStock);
    if (hasLooseUnits) {
      return "$displayStock $pluralized (+${stockRemainder}u)";
    }
    return "$displayStock $pluralized";
  }

  String get displayStockCleanText {
    if (displayStock <= 0) return "Agotado";
    String unidad = presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad";
    return "$displayStock ${pluralize(unidad, displayStock)}";
  }
}
