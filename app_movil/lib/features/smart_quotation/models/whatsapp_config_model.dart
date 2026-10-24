enum WhatsAppMessageStyle {
  commercial,
  compact,
  urgentOffer,
  accountDebt,
  followUp,
  deliveryReady;

  String get label {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return '✨ Comercial Detallado';
      case WhatsAppMessageStyle.compact:
        return '⚡ Resumen Directo';
      case WhatsAppMessageStyle.urgentOffer:
        return '🔥 Cierre de Oferta';
      case WhatsAppMessageStyle.accountDebt:
        return '🔔 Estado de Cuenta';
      case WhatsAppMessageStyle.followUp:
        return '🤝 Seguimiento Amable';
      case WhatsAppMessageStyle.deliveryReady:
        return '📦 Pedido Listo / Envío';
    }
  }

  String get shortLabel {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return 'Comercial';
      case WhatsAppMessageStyle.compact:
        return 'Directo';
      case WhatsAppMessageStyle.urgentOffer:
        return 'Oferta';
      case WhatsAppMessageStyle.accountDebt:
        return 'Cobro';
      case WhatsAppMessageStyle.followUp:
        return 'Seguimiento';
      case WhatsAppMessageStyle.deliveryReady:
        return 'Entrega';
    }
  }

  String get description {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return 'Formato elegante y completo con lista detallada de productos, subtotales, totales y cuentas de pago.';
      case WhatsAppMessageStyle.compact:
        return 'Mensaje ultra-conciso enfocado en la cantidad de ítems y el monto total final para respuestas rápidas.';
      case WhatsAppMessageStyle.urgentOffer:
        return 'Enfocado en descuentos aplicados, ahorro total obtenido y vigencia limitada para motivar la decisión de compra.';
      case WhatsAppMessageStyle.accountDebt:
        return 'Resumen formal con saldo abonado, saldo pendiente de pago y número de cuotas restantes.';
      case WhatsAppMessageStyle.followUp:
        return 'Tono cercano consultando si revisó la cotización o si requiere ajustar cantidades y productos.';
      case WhatsAppMessageStyle.deliveryReady:
        return 'Notificación formal informando que el pedido está empaquetado y listo para retiro en tienda o despacho.';
    }
  }

  static WhatsAppMessageStyle fromString(String? val) {
    if (val == null) return WhatsAppMessageStyle.commercial;
    for (var style in WhatsAppMessageStyle.values) {
      if (style.name == val) return style;
    }
    return WhatsAppMessageStyle.commercial;
  }
}

class WhatsAppConfig {
  WhatsAppMessageStyle style;
  bool showSubtotals; 
  bool showTotalGlobal; 
  
  bool showSavingsSection; 
  bool showDiscountDetail; 

  bool showDebtInfo;     
  bool showDeliveryInfo; 
  bool showInstallmentDetails;
  
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  
  bool showPaymentInfo; 

  bool includeDelivery;
  bool includeValidity;

  String? customIntro;
  String? customClosing;

  bool updateClientData; 
  bool updateBusinessData; 

  WhatsAppConfig({
    this.style = WhatsAppMessageStyle.commercial,
    this.showSubtotals = true,
    this.showTotalGlobal = true,
    this.showSavingsSection = true,
    this.showDiscountDetail = false, 
    this.showDebtInfo = true,    
    this.showDeliveryInfo = true, 
    this.showInstallmentDetails = true,
    this.showBusinessInfo = true,
    this.includeOwnerPhone = true,
    this.includeShopAddress = true,
    this.includeShopRuc = true,
    this.showPaymentInfo = true,
    this.includeDelivery = true,
    this.includeValidity = true,
    this.customIntro,
    this.customClosing,
    this.updateClientData = false,
    this.updateBusinessData = false,
  });

  WhatsAppConfig copyWith({
    WhatsAppMessageStyle? style,
    bool? showSubtotals,
    bool? showTotalGlobal,
    bool? showSavingsSection,
    bool? showDiscountDetail,
    bool? showDebtInfo,
    bool? showDeliveryInfo,
    bool? showInstallmentDetails,
    bool? showBusinessInfo,
    bool? includeOwnerPhone,
    bool? includeShopAddress,
    bool? includeShopRuc,
    bool? showPaymentInfo,
    bool? includeDelivery,
    bool? includeValidity,
    String? customIntro,
    String? customClosing,
    bool? updateClientData,
    bool? updateBusinessData,
  }) {
    return WhatsAppConfig(
      style: style ?? this.style,
      showSubtotals: showSubtotals ?? this.showSubtotals,
      showTotalGlobal: showTotalGlobal ?? this.showTotalGlobal,
      showSavingsSection: showSavingsSection ?? this.showSavingsSection,
      showDiscountDetail: showDiscountDetail ?? this.showDiscountDetail,
      showDebtInfo: showDebtInfo ?? this.showDebtInfo,
      showDeliveryInfo: showDeliveryInfo ?? this.showDeliveryInfo,
      showInstallmentDetails: showInstallmentDetails ?? this.showInstallmentDetails,
      showBusinessInfo: showBusinessInfo ?? this.showBusinessInfo,
      includeOwnerPhone: includeOwnerPhone ?? this.includeOwnerPhone,
      includeShopAddress: includeShopAddress ?? this.includeShopAddress,
      includeShopRuc: includeShopRuc ?? this.includeShopRuc,
      showPaymentInfo: showPaymentInfo ?? this.showPaymentInfo,
      includeDelivery: includeDelivery ?? this.includeDelivery,
      includeValidity: includeValidity ?? this.includeValidity,
      customIntro: customIntro ?? this.customIntro,
      customClosing: customClosing ?? this.customClosing,
      updateClientData: updateClientData ?? this.updateClientData,
      updateBusinessData: updateBusinessData ?? this.updateBusinessData,
    );
  }

  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) {
    return WhatsAppConfig(
      style: WhatsAppMessageStyle.fromString(json['style']),
      showSubtotals: json['showSubtotals'] ?? true,
      showTotalGlobal: json['showTotalGlobal'] ?? true,
      showSavingsSection: json['showSavingsSection'] ?? true,
      showDiscountDetail: json['showDiscountDetail'] ?? false,
      showDebtInfo: json['showDebtInfo'] ?? true,
      showDeliveryInfo: json['showDeliveryInfo'] ?? true,
      showInstallmentDetails: json['showInstallmentDetails'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      includeOwnerPhone: json['includeOwnerPhone'] ?? true,
      includeShopAddress: json['includeShopAddress'] ?? true,
      includeShopRuc: json['includeShopRuc'] ?? true,
      showPaymentInfo: json['showPaymentInfo'] ?? true,
      includeDelivery: json['includeDelivery'] ?? true,
      includeValidity: json['includeValidity'] ?? true,
      customIntro: json['customIntro'],
      customClosing: json['customClosing'],
      updateClientData: json['updateClientData'] ?? false,
      updateBusinessData: json['updateBusinessData'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'style': style.name,
      'showSubtotals': showSubtotals,
      'showTotalGlobal': showTotalGlobal,
      'showSavingsSection': showSavingsSection,
      'showDiscountDetail': showDiscountDetail,
      'showDebtInfo': showDebtInfo,
      'showDeliveryInfo': showDeliveryInfo,
      'showInstallmentDetails': showInstallmentDetails,
      'showBusinessInfo': showBusinessInfo,
      'includeOwnerPhone': includeOwnerPhone,
      'includeShopAddress': includeShopAddress,
      'includeShopRuc': includeShopRuc,
      'showPaymentInfo': showPaymentInfo,
      'includeDelivery': includeDelivery,
      'includeValidity': includeValidity,
      'customIntro': customIntro,
      'customClosing': customClosing,
      'updateClientData': updateClientData,
      'updateBusinessData': updateBusinessData,
    };
  }
}