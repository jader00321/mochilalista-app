enum PdfTheme {
  classic,  // Minimalista Blanco y Negro (ahorro de tinta)
  modern,   // Moderno Azul
  emerald,  // Esmeralda Comercial
  dark,     // Ejecutivo Oscuro
  minimal,  // Minimalista
  burgundy, // Borgoña Elegante
  indigo,   // Índigo Real
}

enum PdfLayoutTemplate {
  executiveModern,   // ✨ Ejecutivo Moderno: franja de acento superior, cabeceras redondeadas, tarjeta destacada de totales
  corporateFramed,   // 🏢 Corporativo Enmarcado: cajas con bordes definidos para negocio/cliente, tabla cuadriculada, firma/sello
  commercialCatalog, // 🛍️ Catálogo Comercial: fotos destacadas (42x42), badges de oferta/ahorro resaltados
  compactWholesale,  // ⚡ Compacto Mayorista: alta densidad de filas para cotizaciones con muchos productos en 1 página
}

enum PdfPageSize {
  a4,      // Hoja completa A4
  ticket80 // Rollo térmico 80mm
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
  PdfLayoutTemplate layoutTemplate;
  PdfPageSize pageSize;

  bool showClientName;       
  String? customClientName;    // Nombre editable del cliente para el documento
  bool showInstitutionInfo; 
  
  bool showBusinessInfo; 
  bool includeOwnerPhone;
  bool includeShopAddress;
  bool includeShopRuc;
  bool includeLogo;
  
  bool showInstallments; 
  bool showPaymentAccounts;    // Mostrar cuentas de pago Yape/Plin al pie
  bool showStatusStamp;        // Sello visual PAGADO / PENDIENTE
  String? footerNote;          // Nota al pie (ej: "Cotización válida por 7 días")

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
    this.layoutTemplate = PdfLayoutTemplate.executiveModern,
    this.pageSize = PdfPageSize.a4,
    this.showClientName = true,      
    this.customClientName,
    this.showInstitutionInfo = true, 
    this.showBusinessInfo = true,
    this.includeOwnerPhone = true,
    this.includeShopAddress = true,
    this.includeShopRuc = true,
    this.includeLogo = true,
    this.showInstallments = true,
    this.showPaymentAccounts = false,
    this.showStatusStamp = false,
    this.footerNote,
  });

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
      layoutTemplate: PdfLayoutTemplate.values.firstWhere(
        (e) => e.name == json['layoutTemplate'],
        orElse: () => PdfLayoutTemplate.executiveModern
      ),
      pageSize: PdfPageSize.values.firstWhere(
        (e) => e.name == json['pageSize'],
        orElse: () => PdfPageSize.a4
      ),
      showClientName: json['showClientName'] ?? true,
      customClientName: json['customClientName'],
      showInstitutionInfo: json['showInstitutionInfo'] ?? true,
      showBusinessInfo: json['showBusinessInfo'] ?? true,
      includeOwnerPhone: json['includeOwnerPhone'] ?? true,
      includeShopAddress: json['includeShopAddress'] ?? true,
      includeShopRuc: json['includeShopRuc'] ?? true,
      includeLogo: json['includeLogo'] ?? true,
      showInstallments: json['showInstallments'] ?? true,
      showPaymentAccounts: json['showPaymentAccounts'] ?? false,
      showStatusStamp: json['showStatusStamp'] ?? false,
      footerNote: json['footerNote'],
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
      'layoutTemplate': layoutTemplate.name,
      'pageSize': pageSize.name,
      'showClientName': showClientName,
      'customClientName': customClientName,
      'showInstitutionInfo': showInstitutionInfo,
      'showBusinessInfo': showBusinessInfo,
      'includeOwnerPhone': includeOwnerPhone,
      'includeShopAddress': includeShopAddress,
      'includeShopRuc': includeShopRuc,
      'includeLogo': includeLogo,
      'showInstallments': showInstallments,
      'showPaymentAccounts': showPaymentAccounts,
      'showStatusStamp': showStatusStamp,
      'footerNote': footerNote,
    };
  }

  PdfConfig copyWith({
    bool? showTotalGlobal,
    bool? showTotalSavings,
    bool? showProductUnit,
    bool? showProductUnitPrice,
    bool? showProductSubtotal,
    bool? showProductSavings,
    bool? showTransactionDetails,
    String? documentTitle,
    bool? showImages,
    PdfTheme? theme,
    PdfLayoutTemplate? layoutTemplate,
    PdfPageSize? pageSize,
    bool? showClientName,
    String? customClientName,
    bool? showInstitutionInfo,
    bool? showBusinessInfo,
    bool? includeOwnerPhone,
    bool? includeShopAddress,
    bool? includeShopRuc,
    bool? includeLogo,
    bool? showInstallments,
    bool? showPaymentAccounts,
    bool? showStatusStamp,
    String? footerNote,
  }) {
    return PdfConfig(
      showTotalGlobal: showTotalGlobal ?? this.showTotalGlobal,
      showTotalSavings: showTotalSavings ?? this.showTotalSavings,
      showProductUnit: showProductUnit ?? this.showProductUnit,
      showProductUnitPrice: showProductUnitPrice ?? this.showProductUnitPrice,
      showProductSubtotal: showProductSubtotal ?? this.showProductSubtotal,
      showProductSavings: showProductSavings ?? this.showProductSavings,
      showTransactionDetails: showTransactionDetails ?? this.showTransactionDetails,
      documentTitle: documentTitle ?? this.documentTitle,
      showImages: showImages ?? this.showImages,
      theme: theme ?? this.theme,
      layoutTemplate: layoutTemplate ?? this.layoutTemplate,
      pageSize: pageSize ?? this.pageSize,
      showClientName: showClientName ?? this.showClientName,
      customClientName: customClientName ?? this.customClientName,
      showInstitutionInfo: showInstitutionInfo ?? this.showInstitutionInfo,
      showBusinessInfo: showBusinessInfo ?? this.showBusinessInfo,
      includeOwnerPhone: includeOwnerPhone ?? this.includeOwnerPhone,
      includeShopAddress: includeShopAddress ?? this.includeShopAddress,
      includeShopRuc: includeShopRuc ?? this.includeShopRuc,
      includeLogo: includeLogo ?? this.includeLogo,
      showInstallments: showInstallments ?? this.showInstallments,
      showPaymentAccounts: showPaymentAccounts ?? this.showPaymentAccounts,
      showStatusStamp: showStatusStamp ?? this.showStatusStamp,
      footerNote: footerNote ?? this.footerNote,
    );
  }
}