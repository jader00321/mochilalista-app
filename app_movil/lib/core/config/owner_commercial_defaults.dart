// Archivo declarativo oficial de defaults comerciales de MochilaLista POS Móvil.
// Ruta destino: app_movil/lib/core/config/owner_commercial_defaults.dart
// Puedes reemplazar este archivo completo (Ctrl+A -> Ctrl+V o descarga .dart)
// desde MochilaLista Admin > Sincronización Comercial MLC1 (Vía 2).

/// Parámetros comerciales compilados por defecto para MochilaLista POS Móvil.
///
/// Archivo 100 % declarativo y puro (sin dependencias de Flutter UI ni SQLite).
class OwnerCommercialDefaults {
  static const int commercialSyncDefaultRevision = 0;
  static const String authorFullName = 'Julio Angello Vasquez Navarro';
  static const String appCommercialName = 'MochilaLista';
  static const String legalFrameworkNotice =
      'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI';
  static const String personalDataLawNotice =
      'Ley N° 29733 (Ley de Protección de Datos Personales)';
  static const String supportPhone = '+51 922 836 879';
  static const String supportWhatsAppUrl = 'https://wa.me/51922836879';
  static const String officialWebsite = 'https://mochilalista.com';
  static const String yapePlinHolder = 'Julio Angello Vasquez Navarro';
  static const String yapePlinPhone = '922836879';
  static const String bcpAccountHolder = '';
  static const String bcpAccountNumber = '';
  static const String bcpCciNumber = '';
  static const String bbvaAccountHolder = '';
  static const String bbvaAccountNumber = '';
  static const String bbvaCciNumber = '';

  /// Catálogo comercial por defecto compilado para nuevas versiones APK
  static const Map<String, Map<String, Object>> defaultCommercialPlans = {
    'mensual': {
      'pr': 35.00,
      'd': 30,
      'ai': 50,
      'um': 0,
      'lb': 'Mensual',
      'ds': 'Ideal para probar el sistema mes a mes',
    },
    'trimestral': {
      'pr': 90.00,
      'd': 90,
      'ai': 180,
      'um': 0,
      'lb': 'Trimestral',
      'ds': 'Ahorro de S/ 15 vs mensual (S/ 30/mes)',
    },
    'semestral': {
      'pr': 160.00,
      'd': 180,
      'ai': 450,
      'um': 0,
      'lb': 'Semestral',
      'ds': 'Ahorro de S/ 50 (S/ 26.60/mes)',
    },
    'anual': {
      'pr': 280.00,
      'd': 365,
      'ai': 1200,
      'um': 0,
      'lb': 'Anual',
      'ds': 'Mayor ahorro comercial (S/ 23.30/mes)',
    },
    'perpetua': {
      'pr': 850.00,
      'd': 99999,
      'ai': 200,
      'um': 12,
      'lb': 'Perpetua',
      'ds': 'Pago único de por vida + 12 meses de updates',
    },
    'bolsa_extra_ia': {
      'pr': 20.00,
      'd': 0,
      'ai': 150,
      'um': 0,
      'lb': 'Bolsa Extra IA',
      'ds': '+150 escaneos acumulativos sin vencimiento para cualquier plan',
    },
    'pase_anual_updates': {
      'pr': 150.00,
      'd': 0,
      'ai': 100,
      'um': 12,
      'lb': 'Pase Anual de Updates',
      'ds': '12 meses extra de nuevas funciones para Licencias Perpetuas',
    },
    'migracion': {
      'pr': 40.00,
      'd': 0,
      'ai': 0,
      'um': 0,
      'lb': 'Tarifa Técnica de Migración',
      'ds': 'Reasignación criptográfica oficial por cambio de equipo',
    },
  };
}
