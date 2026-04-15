enum PdfTheme {
  classic, // B/N Estricto
  modern,  // Azul corporativo
  minimal  // Limpio
}

class PdfConfig {
  // Datos Financieros Globales
  bool showTotalGlobal;
  bool showTotalSavings; 

  // Datos Financieros (Columnas por Producto)
  bool showProductUnit;       // Mostrar columna "Unid."
  bool showProductUnitPrice;  // Mostrar precio S/ Unitario
  bool showProductSubtotal;   // Mostrar precio S/ Total por línea
  bool showProductSavings;    // Mostrar precio original tachado (si hay descuento)

  // Datos de Transacción
  bool showTransactionDetails; 
  String? documentTitle;       

  // Datos Visuales
  bool showImages;
  PdfTheme theme;

  // Datos de Cliente 
  bool showClientName;      
  bool showInstitutionInfo; // Sirve para Colegio/Grado (Proformas) o Notas (Caja Rápida)
  
  // Privacidad del Negocio
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  bool includeLogo;

  PdfConfig({
    this.showTotalGlobal = true,
    this.showTotalSavings = true, 
    
    // Opciones de Producto por defecto
    this.showProductUnit = true,
    this.showProductUnitPrice = true,
    this.showProductSubtotal = true,
    this.showProductSavings = true,
    
    this.showTransactionDetails = true, 
    this.documentTitle, 
    this.showImages = false,
    this.theme = PdfTheme.modern,
    this.showClientName = true,      
    this.showInstitutionInfo = true, 
    this.showBusinessInfo = true,
    this.includeOwnerPhone = true,
    this.includeShopAddress = true,
    this.includeShopRuc = true,
    this.includeLogo = true,
  });
}