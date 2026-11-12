import 'package:flutter/material.dart';

enum WhatsAppMessageStyle {
  commercial,
  wholesale,
  compact,
  school,
  urgentOffer,
  accountDebt,
  followUp,
  deliveryReady;

  String get label {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return 'Estándar / Pedido';
      case WhatsAppMessageStyle.wholesale:
        return 'Mayorista / Negocio';
      case WhatsAppMessageStyle.compact:
        return 'Resumen Rápido';
      case WhatsAppMessageStyle.school:
        return 'Lista Escolar';
      case WhatsAppMessageStyle.urgentOffer:
        return 'Cierre de Oferta';
      case WhatsAppMessageStyle.accountDebt:
        return 'Estado de Cuenta';
      case WhatsAppMessageStyle.followUp:
        return 'Seguimiento Amable';
      case WhatsAppMessageStyle.deliveryReady:
        return 'Pedido Listo / Envío';
    }
  }

  IconData get icon {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return Icons.shopping_bag_outlined;
      case WhatsAppMessageStyle.wholesale:
        return Icons.storefront_rounded;
      case WhatsAppMessageStyle.compact:
        return Icons.bolt_rounded;
      case WhatsAppMessageStyle.school:
        return Icons.school_outlined;
      case WhatsAppMessageStyle.urgentOffer:
        return Icons.local_offer_rounded;
      case WhatsAppMessageStyle.accountDebt:
        return Icons.account_balance_wallet_rounded;
      case WhatsAppMessageStyle.followUp:
        return Icons.handshake_rounded;
      case WhatsAppMessageStyle.deliveryReady:
        return Icons.local_shipping_rounded;
    }
  }

  String get shortLabel {
    switch (this) {
      case WhatsAppMessageStyle.commercial:
        return 'Pedido';
      case WhatsAppMessageStyle.wholesale:
        return 'Mayorista';
      case WhatsAppMessageStyle.compact:
        return 'Rápido';
      case WhatsAppMessageStyle.school:
        return 'Escolar';
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
        return 'Formato elegante y completo para pedidos de compra variados con productos, unitarios, totales y cuentas de pago.';
      case WhatsAppMessageStyle.wholesale:
        return 'Proforma comercial B2B para pedidos al por mayor con especificación de empaques, cajas, fardos y precios por volumen.';
      case WhatsAppMessageStyle.compact:
        return 'Mensaje ultra-conciso enfocado en la cantidad de ítems y el monto total final para respuestas instantáneas.';
      case WhatsAppMessageStyle.school:
        return 'Cotización de útiles escolares detallando colegio, alumno, grado y lista de útiles organizados.';
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
  bool showUnitPrices; 
  bool showBrandPackage; 
  bool showClientData; 
  
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
    this.showUnitPrices = true,
    this.showBrandPackage = true,
    this.showClientData = true,
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
    bool? showUnitPrices,
    bool? showBrandPackage,
    bool? showClientData,
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
      showUnitPrices: showUnitPrices ?? this.showUnitPrices,
      showBrandPackage: showBrandPackage ?? this.showBrandPackage,
      showClientData: showClientData ?? this.showClientData,
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

  /// Aplica la Matriz de Configuración oficial de las Plantillas por Escenario
  void applyTemplateStyle(WhatsAppMessageStyle newStyle) {
    style = newStyle;
    switch (newStyle) {
      case WhatsAppMessageStyle.commercial:
        showSubtotals = true;
        showUnitPrices = true;
        showBrandPackage = true;
        showClientData = true;
        showSavingsSection = true;
        showDiscountDetail = true;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = true;
        includeValidity = true;
        includeDelivery = true;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = true;
        break;
      case WhatsAppMessageStyle.wholesale:
        showSubtotals = true;
        showUnitPrices = true;
        showBrandPackage = true;
        showClientData = true;
        showSavingsSection = true;
        showDiscountDetail = true;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = true;
        includeValidity = true;
        includeDelivery = true;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = true;
        break;
      case WhatsAppMessageStyle.school:
        showSubtotals = true;
        showUnitPrices = true;
        showBrandPackage = true;
        showClientData = true;
        showSavingsSection = true;
        showDiscountDetail = true;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = true;
        includeValidity = true;
        includeDelivery = true;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = true;
        break;
      case WhatsAppMessageStyle.compact:
        showSubtotals = true;
        showSavingsSection = false;
        showDiscountDetail = false;
        showTotalGlobal = true;
        showBusinessInfo = false;
        showPaymentInfo = true;
        includeValidity = false;
        includeDelivery = false;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = false;
        break;
      case WhatsAppMessageStyle.urgentOffer:
        showSubtotals = true;
        showSavingsSection = true;
        showDiscountDetail = true;
        showTotalGlobal = true;
        showBusinessInfo = false;
        showPaymentInfo = true;
        includeValidity = true;
        includeDelivery = false;
        showDebtInfo = false;
        showInstallmentDetails = false;
        showDeliveryInfo = false;
        break;
      case WhatsAppMessageStyle.accountDebt:
        showSubtotals = true;
        showSavingsSection = false;
        showDiscountDetail = false;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = true;
        includeValidity = false;
        includeDelivery = false;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = false;
        break;
      case WhatsAppMessageStyle.followUp:
        showSubtotals = true;
        showSavingsSection = false;
        showDiscountDetail = false;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = false;
        includeValidity = true;
        includeDelivery = false;
        showDebtInfo = false;
        showInstallmentDetails = false;
        showDeliveryInfo = false;
        break;
      case WhatsAppMessageStyle.deliveryReady:
        showSubtotals = false;
        showSavingsSection = false;
        showDiscountDetail = false;
        showTotalGlobal = true;
        showBusinessInfo = true;
        showPaymentInfo = true;
        includeValidity = false;
        includeDelivery = true;
        showDebtInfo = true;
        showInstallmentDetails = true;
        showDeliveryInfo = true;
        break;
    }
  }

  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) {
    return WhatsAppConfig(
      style: WhatsAppMessageStyle.fromString(json['style']),
      showSubtotals: json['showSubtotals'] ?? true,
      showTotalGlobal: json['showTotalGlobal'] ?? true,
      showUnitPrices: json['showUnitPrices'] ?? true,
      showBrandPackage: json['showBrandPackage'] ?? true,
      showClientData: json['showClientData'] ?? true,
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
      'showUnitPrices': showUnitPrices,
      'showBrandPackage': showBrandPackage,
      'showClientData': showClientData,
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