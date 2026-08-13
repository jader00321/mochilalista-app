class PromotionRuleModel {
  final int id;
  final int campanaId;
  final int presentacionId;
  final String tipoDescuento;
  final double valorDescuento;
  final int? limiteStockPromocional;

  PromotionRuleModel({
    required this.id,
    required this.campanaId,
    required this.presentacionId,
    required this.tipoDescuento,
    required this.valorDescuento,
    this.limiteStockPromocional,
  });

  factory PromotionRuleModel.fromJson(Map<String, dynamic> json) {
    return PromotionRuleModel(
      id: json['id'] as int,
      campanaId: json['campana_id'] as int,
      presentacionId: json['presentacion_id'] as int,
      tipoDescuento: json['tipo_descuento'] as String,
      valorDescuento: (json['valor_descuento'] as num).toDouble(),
      limiteStockPromocional: json['limite_stock_promocional'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campana_id': campanaId,
      'presentacion_id': presentacionId,
      'tipo_descuento': tipoDescuento,
      'valor_descuento': valorDescuento,
      'limite_stock_promocional': limiteStockPromocional,
    };
  }
}
