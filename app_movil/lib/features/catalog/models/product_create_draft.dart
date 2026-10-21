/// 📦 Modelo para el Borrador Temporal de Crear Producto (100% en memoria)
class ProductCreateDraft {
  final String name;
  final int? brandId;
  final String? deferredBrandName;
  final int? categoryId;
  final String? deferredCategoryName;
  final int? generalProviderId;
  final String? deferredGeneralProviderName;
  final int generalState;

  final String description;
  final String imageUrl;
  final String barcode;

  final List<Map<String, dynamic>> presentations;
  final DateTime lastUpdated;

  ProductCreateDraft({
    required this.name,
    this.brandId,
    this.deferredBrandName,
    this.categoryId,
    this.deferredCategoryName,
    this.generalProviderId,
    this.deferredGeneralProviderName,
    this.generalState = 2,
    this.description = "",
    this.imageUrl = "",
    this.barcode = "",
    required this.presentations,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Determina si el borrador tiene datos significativos para mostrar indicadores
  bool get hasMeaningfulData {
    if (name.trim().isNotEmpty) return true;
    if (brandId != null && brandId != 0) return true;
    if (deferredBrandName != null && deferredBrandName!.trim().isNotEmpty) {
      return true;
    }
    if (categoryId != null && categoryId != 0) return true;
    if (deferredCategoryName != null &&
        deferredCategoryName!.trim().isNotEmpty) {
      return true;
    }
    if (generalProviderId != null && generalProviderId != 0) {
      return true;
    }
    if (deferredGeneralProviderName != null &&
        deferredGeneralProviderName!.trim().isNotEmpty) {
      return true;
    }
    if (description.trim().isNotEmpty) return true;
    if (imageUrl.trim().isNotEmpty) return true;
    if (barcode.trim().isNotEmpty) return true;
    if (presentations.length > 1) return true;

    if (presentations.isNotEmpty) {
      final p0 = presentations.first;
      final spec = (p0['specific'] ?? '').toString().trim();
      final pVenta = (p0['precioVenta'] ?? '').toString().trim();
      final cost = (p0['costoPres'] ?? '').toString().trim();
      final img = (p0['image'] ?? '').toString().trim();
      final bar = (p0['barcode'] ?? '').toString().trim();
      final stockInit = (p0['stockInicial'] ?? '').toString().trim();
      final stockFinal = (p0['stockFinal'] ?? '').toString().trim();
      final defProv = (p0['deferredProviderName'] ?? '').toString().trim();
      final provId = p0['proveedor_id'];
      final cantCompra = (p0['cantCompra'] ?? '').toString().trim();
      final totalPago = (p0['totalPago'] ?? '').toString().trim();

      final double pVentaVal = double.tryParse(pVenta) ?? 0.0;
      final double costVal = double.tryParse(cost) ?? 0.0;
      final int stockInitVal = int.tryParse(stockInit) ?? 0;
      final int stockFinalVal = int.tryParse(stockFinal) ?? 0;
      final double cantCompraVal = double.tryParse(cantCompra) ?? 0.0;
      final double totalPagoVal = double.tryParse(totalPago) ?? 0.0;

      if (spec.isNotEmpty ||
          pVentaVal > 0.0 ||
          costVal > 0.0 ||
          img.isNotEmpty ||
          bar.isNotEmpty ||
          defProv.isNotEmpty ||
          (provId != null && provId != 0) ||
          stockInitVal > 0 ||
          stockFinalVal > 0 ||
          cantCompraVal > 0.0 ||
          totalPagoVal > 0.0 ||
          p0['activeRoundingTarget'] != null ||
          p0['preRoundedPrice'] != null) {
        return true;
      }
    }

    return false;
  }
}
