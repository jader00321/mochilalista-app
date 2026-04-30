class WhatsAppConfig {
  bool showSubtotals; 
  bool showTotalGlobal; 
  
  bool showSavingsSection; 
  bool showDiscountDetail; 

  bool showDebtInfo;     
  bool showDeliveryInfo; 
  
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  
  bool showPaymentInfo; 

  bool updateClientData; 
  bool updateBusinessData; 

  WhatsAppConfig({
    this.showSubtotals = true,
    this.showTotalGlobal = true,
    this.showSavingsSection = true,
    this.showDiscountDetail = false, 
    this.showDebtInfo = true,    
    this.showDeliveryInfo = true, 
    this.showBusinessInfo = true,
    this.includeOwnerPhone = true,
    this.includeShopAddress = true,
    this.includeShopRuc = true,
    this.showPaymentInfo = true,
    this.updateClientData = false,
    this.updateBusinessData = false,
  });

  // Agregado para guardarlo offline
  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) {
    return WhatsAppConfig(
      showSubtotals: json['showSubtotals'] ?? true,
      showTotalGlobal: json['showTotalGlobal'] ?? true,
      showSavingsSection: json['showSavingsSection'] ?? true,
      showDiscountDetail: json['showDiscountDetail'] ?? false,
      showDebtInfo: json['showDebtInfo'] ?? true,
      showDeliveryInfo: json['showDeliveryInfo'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      includeOwnerPhone: json['includeOwnerPhone'] ?? true,
      includeShopAddress: json['includeShopAddress'] ?? true,
      includeShopRuc: json['includeShopRuc'] ?? true,
      showPaymentInfo: json['showPaymentInfo'] ?? true,
      updateClientData: json['updateClientData'] ?? false,
      updateBusinessData: json['updateBusinessData'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showSubtotals': showSubtotals,
      'showTotalGlobal': showTotalGlobal,
      'showSavingsSection': showSavingsSection,
      'showDiscountDetail': showDiscountDetail,
      'showDebtInfo': showDebtInfo,
      'showDeliveryInfo': showDeliveryInfo,
      'showBusinessInfo': showBusinessInfo,
      'includeOwnerPhone': includeOwnerPhone,
      'includeShopAddress': includeShopAddress,
      'includeShopRuc': includeShopRuc,
      'showPaymentInfo': showPaymentInfo,
      'updateClientData': updateClientData,
      'updateBusinessData': updateBusinessData,
    };
  }
}