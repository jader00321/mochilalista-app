import 'package:app_movil/core/config/owner_commercial_defaults.dart';

/// Parámetros centralizados de identidad legal, titularidad de propiedad intelectual
/// y canales oficiales de soporte de MochilaLista.
class OwnerLegalIdentity {
  // Identidad oficial del Titular y Autor (delegada a OwnerCommercialDefaults)
  static const int commercialSyncDefaultRevision =
      OwnerCommercialDefaults.commercialSyncDefaultRevision;
  static const String authorFullName = OwnerCommercialDefaults.authorFullName;
  static const String appCommercialName =
      OwnerCommercialDefaults.appCommercialName;
  static const String currentAppVersion = "9.41.0";
  static const String currentAppVersionWithBuild = "9.41.0+85";
  static const String legalJurisdiction = "Lima, República del Perú";
  static const String legalFrameworkNotice =
      OwnerCommercialDefaults.legalFrameworkNotice;
  static const String personalDataLawNotice =
      OwnerCommercialDefaults.personalDataLawNotice;

  // Títulos y Subtítulos Oficiales EULA
  static const String legalEulaTitle = "Términos de Licencia (EULA)";
  static const String legalSubtitleCommercial = "MochilaLista POS Comercial";
  static const String legalAuthorTitle = "Autor y Titular: $authorFullName";

  // Canales Oficiales de Soporte y Gestión de Licencias
  static const String supportPhone = OwnerCommercialDefaults.supportPhone;
  static const String supportWhatsAppUrl =
      OwnerCommercialDefaults.supportWhatsAppUrl;
  static const String officialWebsite = OwnerCommercialDefaults.officialWebsite;

  // Medios de Pago Parametrizados (Perú)
  static const String yapePlinHolder = OwnerCommercialDefaults.yapePlinHolder;
  static const String yapePlinPhone = OwnerCommercialDefaults.yapePlinPhone;
  static const String bcpAccountHolder =
      OwnerCommercialDefaults.bcpAccountHolder;
  static const String bcpAccountNumber =
      OwnerCommercialDefaults.bcpAccountNumber;
  static const String bcpCciNumber = OwnerCommercialDefaults.bcpCciNumber;
  static const String bbvaAccountHolder =
      OwnerCommercialDefaults.bbvaAccountHolder;
  static const String bbvaAccountNumber =
      OwnerCommercialDefaults.bbvaAccountNumber;
  static const String bbvaCciNumber = OwnerCommercialDefaults.bbvaCciNumber;

  /// Catálogo comercial por defecto compilado para nuevas versiones APK
  static const Map<String, Map<String, Object>> defaultCommercialPlans =
      OwnerCommercialDefaults.defaultCommercialPlans;

  /// Formatea gramaticalmente el nombre del plan con su artículo correspondiente
  static String formatPlanArticleName(String planName) {
    final lower = planName.toLowerCase();
    if (lower.contains('update') || lower.contains('pase')) {
      return "el Pase Anual de Actualizaciones";
    }
    if (lower.contains('perpetua') || lower.contains('perpetuo')) {
      return "la Licencia Perpetua";
    }
    if (lower.contains('bolsa') ||
        lower.contains('extra') ||
        RegExp(r'\bia\b').hasMatch(lower)) {
      return "una Bolsa Extra de IA (150 escaneos)";
    }
    if (lower.contains('mensual')) {
      return "el Plan Mensual";
    }
    if (lower.contains('trimestral')) {
      return "el Plan Trimestral";
    }
    if (lower.contains('semestral')) {
      return "el Plan Semestral";
    }
    if (lower.contains('anual')) {
      return "el Plan Anual";
    }
    return "el $planName";
  }

  /// Construye el mensaje comercial oficial prellenado para solicitar planes
  static String buildPlanOrderMessage({
    required String planName,
    required String price,
    required String hardwareId,
  }) {
    final formattedPlan = formatPlanArticleName(planName);
    return "Hola Julio Angello, deseo solicitar $formattedPlan ($price) para MochilaLista.\n"
        "Mi código de dispositivo (Hardware ID) es: $hardwareId\n"
        "Adjunto mi comprobante de pago por Yape / Transferencia bancaria.";
  }

  /// Construye la URI oficial de WhatsApp a partir de un mensaje personalizado
  static Uri buildCustomWhatsAppOrderUri(
    String customMessage, {
    String? supportPhoneOverride,
  }) {
    final targetPhone = (supportPhoneOverride?.trim().isNotEmpty ?? false)
        ? supportPhoneOverride!
        : supportPhone;
    final cleanPhone = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(customMessage);
    return Uri.parse("https://wa.me/$cleanPhone?text=$encoded");
  }

  /// Construye la URI oficial de WhatsApp con mensaje comercial prellenado para solicitar planes
  static String buildPlanWhatsAppUri({
    required String planName,
    required String price,
    required String hardwareId,
    String? supportPhoneOverride,
  }) {
    final text = buildPlanOrderMessage(
      planName: planName,
      price: price,
      hardwareId: hardwareId,
    );
    return buildCustomWhatsAppOrderUri(
      text,
      supportPhoneOverride: supportPhoneOverride,
    ).toString();
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
