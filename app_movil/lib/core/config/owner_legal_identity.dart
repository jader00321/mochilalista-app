/// Parámetros centralizados de identidad legal, titularidad de propiedad intelectual
/// y canales oficiales de soporte de MochilaLista.
class OwnerLegalIdentity {
  // Identidad oficial del Titular y Autor
  static const String authorFullName = "Julio Angello Vasquez Navarro";
  static const String appCommercialName = "MochilaLista";
  static const String currentAppVersion = "9.31.0";
  static const String currentAppVersionWithBuild = "9.31.0+75";
  static const String legalJurisdiction = "Lima, República del Perú";
  static const String legalFrameworkNotice =
      "Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI";
  static const String personalDataLawNotice =
      "Ley N° 29733 (Ley de Protección de Datos Personales)";

  // Títulos y Subtítulos Oficiales EULA
  static const String legalEulaTitle = "Términos de Licencia (EULA)";
  static const String legalSubtitleCommercial = "MochilaLista POS Comercial";
  static const String legalAuthorTitle = "Autor y Titular: Julio Angello Vasquez Navarro";

  // Canales Oficiales de Soporte y Gestión de Licencias
  static const String supportPhone = "+51 922 836 879";
  static const String supportWhatsAppUrl = "https://wa.me/51922836879";
  static const String officialWebsite = "https://mochilalista.com";

  // Medios de Pago Parametrizados (Perú)
  static const String yapePlinHolder = "Julio Angello Vasquez Navarro";
  static const String bcpAccountNumber = ""; // Configurable
  static const String bcpCciNumber = ""; // Configurable
  static const String bbvaAccountNumber = ""; // Configurable
  static const String bbvaCciNumber = ""; // Configurable

  /// Construye la URI oficial de WhatsApp con mensaje comercial prellenado para solicitar planes
  static String buildPlanWhatsAppUri({
    required String planName,
    required String price,
    required String hardwareId,
  }) {
    final cleanPhone = supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = "Hola Julio Angello, deseo solicitar el $planName ($price) para MochilaLista.\n"
        "Mi código de dispositivo (Hardware ID) es: $hardwareId\n"
        "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.";
    final encoded = Uri.encodeComponent(text);
    return "https://wa.me/$cleanPhone?text=$encoded";
  }

  // Leyenda Legal Estándar para Documentos y Reportes
  static String get watermarkNotice =>
      "$appCommercialName © 2026 $authorFullName. Todos los derechos reservados. $legalFrameworkNotice.";

  // Leyenda de Ticket de Impresora Térmica Bluetooth
  static String get ticketFooterLegal =>
      "Comprobante emitido con $appCommercialName POS\n"
      "Software propiedad de $authorFullName\n"
      "Soporte: $supportPhone";

  // Identificador de Licencia para Cabeceras
  static String getLicenseAttribution({
    required String businessName,
    required String rucDni,
  }) {
    return "Licencia Autorizada para: $businessName (Doc: $rucDni)\n"
        "Desarrollado y licenciado exclusivamente por $authorFullName";
  }
}
