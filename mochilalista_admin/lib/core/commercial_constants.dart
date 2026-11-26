/// Única fuente de verdad para constantes comerciales, huellas criptográficas
/// y mapeos canónicos de productos en `mochilalista_admin`.
class CommercialConstants {
  CommercialConstants._();

  /// Huella SHA-256 oficial del certificado comercial RSA-4096 de Julio Angello Vasquez Navarro.
  static const String officialSignerSha256 =
      '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20';

  static const String defaultAuthorName = 'Julio Angello Vasquez Navarro';
  static const String defaultCommercialName = 'MochilaLista';
  static const String defaultSupportPhone = '+51 922 836 879';
  static const String defaultSupportWhatsAppUrl = 'https://wa.me/51922836879';
  static const String defaultOfficialWebsite = 'https://mochilalista.com';
  static const String defaultLegalFramework =
      'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI Perú';
  static const String defaultPersonalDataLaw =
      'Ley N° 29733 (Ley de Protección de Datos Personales)';
  static const String defaultYapePlinPhone = '922836879';

  /// Orden y mapeo oficial de los 8 ítems comerciales hacia IDs de la app móvil (`MLC1`).
  static const Map<String, String> catalogSlugToSyncId = {
    'MENSUAL': 'mensual',
    'TRIMESTRAL': 'trimestral',
    'SEMESTRAL': 'semestral',
    'ANUAL': 'anual',
    'PERPETUO_LIBERADO': 'perpetua',
    'RECARGA_IA_150': 'bolsa_extra_ia',
    'PASE_ACTUALIZACION_ANUAL': 'pase_anual_updates',
    'HARDWARE_MIGRATION_FEE': 'migracion',
  };

  static const Set<String> allowedMlc1ProductIds = {
    'mensual',
    'trimestral',
    'semestral',
    'anual',
    'perpetua',
    'bolsa_extra_ia',
    'pase_anual_updates',
    'migracion',
  };

  static const List<String> masterExcelPlanOrder = [
    'TRIAL',
    'MENSUAL',
    'TRIMESTRAL',
    'SEMESTRAL',
    'ANUAL',
    'PERPETUO_LIBERADO',
    'PASE_ACTUALIZACION_ANUAL',
    'RECARGA_IA_150',
    'EXTENSION_CORTESIA',
    'BONO_IA_PERSONALIZADO',
    'ABONO_PARCIAL',
    'SERVICIO_MIGRACION',
  ];

  /// Normaliza los slugs comerciales con tolerancia a alias oficiales.
  static String normalizePlanSlug(String rawPlan) {
    final clean = rawPlan.toUpperCase().trim();
    if (clean == 'PASE_UPDATES_12M' || clean == 'PASE_ANUAL_UPDATES') {
      return 'PASE_ACTUALIZACION_ANUAL';
    }
    if (clean == 'PERPETUO' || clean == 'PERPETUA') {
      return 'PERPETUO_LIBERADO';
    }
    return clean;
  }

  /// Tabla oficial de cuota IA base acumulativa acreditada por plan comercial en `app_movil`.
  static int getCumulativeScansForPlan(String planName) {
    switch (planName.toUpperCase().trim()) {
      case 'TRIAL':
        return 50;
      case 'MENSUAL':
        return 50;
      case 'TRIMESTRAL':
        return 180;
      case 'SEMESTRAL':
        return 450;
      case 'ANUAL':
        return 1200;
      case 'PERPETUO_LIBERADO':
      case 'PERPETUO':
      case 'PERPETUA':
        return 200;
      case 'PASE_ACTUALIZACION_ANUAL':
      case 'PASE_ANUAL_UPDATES':
      case 'PASE_UPDATES_12M':
        return 100;
      case 'RECARGA_IA_150':
        return 150;
      case 'EXTENSION_CORTESIA':
      default:
        return 0;
    }
  }
}
