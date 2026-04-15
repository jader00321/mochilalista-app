class WhatsAppConfig {
  // Datos Financieros
  bool showSubtotals; 
  bool showTotalGlobal; 
  
  // Ahorros y Descuentos
  bool showSavingsSection; 
  bool showDiscountDetail; 

  // --- NUEVO: Gestión Post-Venta ---
  bool showDebtInfo;     // Mostrar saldo pendiente si existe
  bool showDeliveryInfo; // Mostrar estado de entrega y fecha
  
  // Datos del Negocio
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  
  // Información de Pago
  bool showPaymentInfo; 

  // Estado de Edición
  bool updateClientData; 
  bool updateBusinessData; 

  WhatsAppConfig({
    this.showSubtotals = true,
    this.showTotalGlobal = true,
    this.showSavingsSection = true,
    this.showDiscountDetail = false, 
    this.showDebtInfo = true,     // Por defecto activo si hay deuda
    this.showDeliveryInfo = true, // Por defecto activo si hay envíos
    this.showBusinessInfo = true,
    this.includeOwnerPhone = true,
    this.includeShopAddress = true,
    this.includeShopRuc = true,
    this.showPaymentInfo = true,
    this.updateClientData = false,
    this.updateBusinessData = false,
  });
}