enum PdfTheme {
  classic, 
  modern,  
  minimal  
}

class PdfConfig {
  bool showTotalGlobal;
  bool showTotalSavings; 

  bool showProductUnit;      
  bool showProductUnitPrice; 
  bool showProductSubtotal;  
  bool showProductSavings;   

  bool showTransactionDetails; 
  String? documentTitle;       

  bool showImages;
  PdfTheme theme;

  bool showClientName;       
  bool showInstitutionInfo; 
  
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  bool includeLogo;

  PdfConfig({
    this.showTotalGlobal = true,
    this.showTotalSavings = true, 
    
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

  // Agregado para guardarlo en la Base de Datos o SharedPreferences localmente
  factory PdfConfig.fromJson(Map<String, dynamic> json) {
    return PdfConfig(
      showTotalGlobal: json['showTotalGlobal'] ?? true,
      showTotalSavings: json['showTotalSavings'] ?? true,
      showProductUnit: json['showProductUnit'] ?? true,
      showProductUnitPrice: json['showProductUnitPrice'] ?? true,
      showProductSubtotal: json['showProductSubtotal'] ?? true,
      showProductSavings: json['showProductSavings'] ?? true,
      showTransactionDetails: json['showTransactionDetails'] ?? true,
      documentTitle: json['documentTitle'],
      showImages: json['showImages'] ?? false,
      theme: PdfTheme.values.firstWhere(
        (e) => e.name == json['theme'], 
        orElse: () => PdfTheme.modern
      ),
      showClientName: json['showClientName'] ?? true,
      showInstitutionInfo: json['showInstitutionInfo'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      includeOwnerPhone: json['includeOwnerPhone'] ?? true,
      includeShopAddress: json['includeShopAddress'] ?? true,
      includeShopRuc: json['includeShopRuc'] ?? true,
      includeLogo: json['includeLogo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showTotalGlobal': showTotalGlobal,
      'showTotalSavings': showTotalSavings,
      'showProductUnit': showProductUnit,
      'showProductUnitPrice': showProductUnitPrice,
      'showProductSubtotal': showProductSubtotal,
      'showProductSavings': showProductSavings,
      'showTransactionDetails': showTransactionDetails,
      'documentTitle': documentTitle,
      'showImages': showImages,
      'theme': theme.name,
      'showClientName': showClientName,
      'showInstitutionInfo': showInstitutionInfo,
      'showBusinessInfo': showBusinessInfo,
      'includeOwnerPhone': includeOwnerPhone,
      'includeShopAddress': includeShopAddress,
      'includeShopRuc': includeShopRuc,
      'includeLogo': includeLogo,
    };
  }
}