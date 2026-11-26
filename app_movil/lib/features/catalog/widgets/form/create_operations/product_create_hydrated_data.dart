class ProductCreateHydratedData {
  final int? brandId;
  final String? brandName;
  final int? categoryId;
  final String? categoryName;
  final int? generalProviderId;
  final String? generalProviderName;
  final String modoStock;
  final int stockCompartido;
  final double costoBase;

  const ProductCreateHydratedData({
    this.brandId,
    this.brandName,
    this.categoryId,
    this.categoryName,
    this.generalProviderId,
    this.generalProviderName,
    this.modoStock = 'INDEPENDIENTE',
    this.stockCompartido = 0,
    this.costoBase = 0.0,
  });
}
