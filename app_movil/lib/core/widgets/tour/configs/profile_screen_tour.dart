import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Perfil
class ProfileScreenTourKeys {
  final GlobalKey businessCardKey;
  final GlobalKey securityPinKey;
  final GlobalKey printerKey;
  final GlobalKey backupsKey;
  final GlobalKey licenseSupportKey;

  ProfileScreenTourKeys({
    GlobalKey? businessCardKey,
    GlobalKey? securityPinKey,
    GlobalKey? printerKey,
    GlobalKey? backupsKey,
    GlobalKey? licenseSupportKey,
  })  : businessCardKey = businessCardKey ?? GlobalKey(debugLabel: 'profile_tour_business_card'),
        securityPinKey = securityPinKey ?? GlobalKey(debugLabel: 'profile_tour_security_pin'),
        printerKey = printerKey ?? GlobalKey(debugLabel: 'profile_tour_printer'),
        backupsKey = backupsKey ?? GlobalKey(debugLabel: 'profile_tour_backups'),
        licenseSupportKey = licenseSupportKey ?? GlobalKey(debugLabel: 'profile_tour_license_support');
}

/// Configuración de la Guía Turística para la Pantalla de Perfil (ProfileScreen)
class ProfileScreenTour {
  static final ProfileScreenTourKeys defaultKeys = ProfileScreenTourKeys();

  // Getters para compatibilidad
  static GlobalKey get businessCardKey => defaultKeys.businessCardKey;
  static GlobalKey get securityPinKey => defaultKeys.securityPinKey;
  static GlobalKey get printerKey => defaultKeys.printerKey;
  static GlobalKey get backupsKey => defaultKeys.backupsKey;
  static GlobalKey get licenseSupportKey => defaultKeys.licenseSupportKey;

  static ScreenTourConfig buildConfig({ProfileScreenTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'profile_screen',
      screenTitle: 'Perfil y Configuración',
      welcomeSummary:
          'Desde aquí personalizas tu identidad comercial, configuras la seguridad con PIN, gestionas tu impresora térmica y proteges tus respaldos.',
      icon: Icons.manage_accounts_rounded,
      steps: [
        TourStep(
          id: 'step_business_card',
          targetKey: k.businessCardKey,
          title: 'Identidad del Negocio',
          description:
              'Personaliza el nombre comercial, RUC, teléfono de contacto y logotipo oficial que se imprimen en tus tickets y cotizaciones.',
          tip: 'Toca el ícono de cámara sobre el logo para actualizar la imagen de tu tienda.',
          icon: Icons.storefront_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_security_pin',
          targetKey: k.securityPinKey,
          title: 'Seguridad y PIN de Acceso',
          description:
              'Protege los datos sensibles de tu comercio configurando un código PIN de 4 dígitos y bloqueo inteligente por inactividad.',
          tip: 'Evita accesos no autorizados a tus reportes de ganancias y márgenes.',
          icon: Icons.lock_outline_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_printer',
          targetKey: k.printerKey,
          title: 'Impresora Térmica Bluetooth',
          description:
              'Vincula tu impresora térmica para emitir recibos y notas de venta al instante desde tu celular.',
          tip: 'Compatible con modelos estándar Bluetooth de 58mm y 80mm.',
          icon: Icons.print_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_backups',
          targetKey: k.backupsKey,
          title: 'Respaldos y Google Drive',
          description:
              'Protege tu inventario y ventas con copias automáticas en Google Drive o exportando archivos locales cifrados (.mlbg).',
          tip: 'Si cambias de teléfono, podrás restaurar toda tu información en un minuto.',
          icon: Icons.cloud_sync_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_license_support',
          targetKey: k.licenseSupportKey,
          title: 'Licencia Oficial y Soporte',
          description:
              'Revisa tu plan activo, vigencia, Hardware ID y comunícate directamente con soporte oficial por WhatsApp si necesitas asistencia.',
          icon: Icons.verified_user_rounded,
          borderRadius: 14.0,
        ),
      ],
    );
  }
}
