/// Motor financiero para el módulo Scanner.
/// Centraliza todas las fórmulas de cálculo de costos, márgenes y precios
/// para asegurar consistencia entre la lógica de backend (matching engine)
/// y la lógica de frontend (widgets interactivos).
class ScannerCostEngine {
  /// Calcula el costo unitario individual real basado en el pago total.
  /// 
  /// Fórmula: total_pago / (cantidad_comprada * unidades_por_lote)
  /// 
  /// Ejemplo: Compro 0.25 MLL (1 MLL = 1000) a S/ 45.00
  /// costoUnitario = 45.00 / (0.25 * 1000) = 45.00 / 250 = S/ 0.18
  static double calculateUnitCost({
    required double totalPago,
    required double cantidadUmp,
    required int unidadesPorLote,
  }) {
    if (cantidadUmp <= 0 || unidadesPorLote <= 0) return 0.0;
    return totalPago / (cantidadUmp * unidadesPorLote);
  }

  /// Calcula el costo unitario base de la factura (Alias semántico)
  static double calculateInvoiceUnitCost({
    required double totalPago,
    required double cantidadUmp,
    required int unidadesPorLote,
  }) => calculateUnitCost(
    totalPago: totalPago, 
    cantidadUmp: cantidadUmp, 
    unidadesPorLote: unidadesPorLote
  );

  /// Calcula el costo por presentación (ej. Caja x 12, Docena).
  /// 
  /// Fórmula: costo_unitario_individual * unidades_por_venta
  static double calculatePresentationCost({
    required double unitCost,
    required int unidadesPorVenta,
  }) {
    if (unidadesPorVenta <= 0) return 0.0;
    return unitCost * unidadesPorVenta;
  }

  /// Sugiere un precio de venta basado en el costo y un factor de margen.
  /// 
  /// Fórmula: costo_presentacion * factor_margen
  static double suggestSalePrice({
    required double presentationCost,
    required double marginFactor,
  }) {
    return presentationCost * marginFactor;
  }

  /// Calcula el factor de margen inverso basado en precio y costo.
  /// 
  /// Fórmula: precio_venta / costo_presentacion
  static double calculateMargin({
    required double salePrice,
    required double presentationCost,
  }) {
    if (presentationCost <= 0) return 1.35; // Fallback
    return salePrice / presentationCost;
  }

  /// Sugiere un margen dinámico basado en historial o categoría.
  /// Por ahora retorna un valor por defecto, pero está listo para escalar.
  static double suggestDynamicMargin({
    int? categoryId,
    int? negocioId,
    double fallbackMargin = 1.35,
  }) {
    // Nota: En un futuro, implementar query a BD para traer margen promedio de categoría
    return fallbackMargin;
  }

  /// Recalcula el costo unitario por defecto del proveedor (precio de 1 lote)
  static double calculateProviderUmpPrice({
    required double totalPago,
    required double cantidadUmp,
  }) {
    if (cantidadUmp <= 0) return 0.0;
    return totalPago / cantidadUmp;
  }
}
