import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Perfil ([ProfileScreen])
class ProfileScreenTourKeys {
  final GlobalKey businessCardKey;
  final GlobalKey businessDetailsCardKey;
  final GlobalKey completionIndicatorKey;
  final GlobalKey operationalCenterKey;
  final GlobalKey securityPinKey;
  final GlobalKey toursSettingsKey;
  final GlobalKey sessionSwitchKey;
  final GlobalKey dangerZoneKey;
  final GlobalKey printerKey;
  final GlobalKey backupsKey;
  final GlobalKey licenseSupportKey;

  ProfileScreenTourKeys({
    GlobalKey? businessCardKey,
    GlobalKey? businessDetailsCardKey,
    GlobalKey? completionIndicatorKey,
    GlobalKey? operationalCenterKey,
    GlobalKey? securityPinKey,
    GlobalKey? toursSettingsKey,
    GlobalKey? sessionSwitchKey,
    GlobalKey? dangerZoneKey,
    GlobalKey? printerKey,
    GlobalKey? backupsKey,
    GlobalKey? licenseSupportKey,
  }) : businessCardKey =
           businessCardKey ?? GlobalKey(debugLabel: 'profile_tour_business_card'),
       businessDetailsCardKey =
           businessDetailsCardKey ??
           GlobalKey(debugLabel: 'profile_tour_business_details'),
       completionIndicatorKey =
           completionIndicatorKey ??
           GlobalKey(debugLabel: 'profile_tour_completion_indicator'),
       operationalCenterKey =
           operationalCenterKey ??
           GlobalKey(debugLabel: 'profile_tour_operational_center'),
       securityPinKey =
           securityPinKey ?? GlobalKey(debugLabel: 'profile_tour_security_pin'),
       toursSettingsKey =
           toursSettingsKey ?? GlobalKey(debugLabel: 'profile_tour_tours_settings'),
       sessionSwitchKey =
           sessionSwitchKey ?? GlobalKey(debugLabel: 'profile_tour_session_switch'),
       dangerZoneKey =
           dangerZoneKey ?? GlobalKey(debugLabel: 'profile_tour_danger_zone'),
       printerKey =
           printerKey ?? GlobalKey(debugLabel: 'profile_tour_printer'),
       backupsKey =
           backupsKey ?? GlobalKey(debugLabel: 'profile_tour_backups'),
       licenseSupportKey =
           licenseSupportKey ??
           GlobalKey(debugLabel: 'profile_tour_license_support');
}

/// Configuración de la Guía Turística para la Pantalla de Perfil ([ProfileScreen])
class ProfileScreenTour {
  static final ProfileScreenTourKeys defaultKeys = ProfileScreenTourKeys();

  // Getters heredados para compatibilidad
  static GlobalKey get businessCardKey => defaultKeys.businessCardKey;
  static GlobalKey get securityPinKey => defaultKeys.securityPinKey;
  static GlobalKey get printerKey => defaultKeys.printerKey;
  static GlobalKey get backupsKey => defaultKeys.backupsKey;
  static GlobalKey get licenseSupportKey => defaultKeys.licenseSupportKey;

  static ScreenTourConfig buildConfig({ProfileScreenTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'profile_screen',
      screenTitle: 'Perfil y Centro de Control',
      welcomeSummary:
          'Personaliza tu tienda y comprobantes PDF, configura el escáner IA, impresora térmica, respaldos en Drive, Bóveda PIN, cambio de negocio y ciclo de vida del perfil.',
      icon: Icons.manage_accounts_rounded,
      steps: [
        TourStep(
          id: 'step_business_card',
          targetKey: k.businessCardKey,
          title: 'Identidad, Logo y Plan Activo',
          description:
              'Visualiza la foto o logo de tu negocio, el saludo de tu cuenta, el rol activo y los indicadores rápidos. Toca el botón de cámara sobre el logo para actualizar la imagen oficial.',
          tip:
              'La imagen configurada aquí aparecerá en las cabeceras de tus proformas, notas y comprobantes.',
          icon: Icons.storefront_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_business_details_modal',
          targetKey: k.businessDetailsCardKey,
          title: 'Información y Modal del Negocio',
          description:
              'Consulta tu ficha comercial y toca "Editar Datos" o el chip de RUC para abrir el modal del negocio: actualiza nombre comercial, RUC o DNI, dirección, ubicación GPS en mapa, moneda y métodos de pago que salen en PDF.',
          tip:
              'Mantén al día los datos del titular y medios de pago para que tus cotizaciones por WhatsApp y PDF salgan completas.',
          icon: Icons.edit_note_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_profile_completion',
          targetKey: k.completionIndicatorKey,
          title: 'Indicador de Completitud del Perfil',
          description:
              'Mide qué porcentaje de tu identidad comercial está configurado. Toca cualquier chip pendiente (RUC, dirección, GPS, logo o métodos de pago) para ir directo a completarlo.',
          tip:
              'Al alcanzar el 100% tus comprobantes y cotizaciones reflejarán identidad profesional completa y el panel se ocultará.',
          icon: Icons.verified_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_operational_center',
          targetKey: k.operationalCenterKey,
          title: 'Centro Operativo (IA, Impresora, Drive y Licencia)',
          description:
              'Accede en un lugar a Datos Personales, Estado y Activación de Licencia, Cotizador Universal IA y API Key, Respaldos locales y Google Drive, tema claro/noche, notificaciones e Impresora Térmica Bluetooth.',
          tip:
              'Genera respaldos periódicos en Google Drive o archivos cifrados .mlbg antes de cambiar de equipo o reinstalar.',
          icon: Icons.tune_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_security_pin',
          targetKey: k.securityPinKey,
          title: 'Seguridad y Bóveda PIN',
          description:
              'Configura o cambia tu PIN de seguridad de 4 dígitos para resguardar el ingreso a tu negocio, márgenes de ganancia, finanzas de clientes y configuraciones críticas.',
          tip:
              'Activar el PIN protege tu información comercial frente a accesos no autorizados.',
          icon: Icons.lock_outline_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_tours_settings',
          targetKey: k.toursSettingsKey,
          title: 'Guías Automáticas y Reinicio',
          description:
              'Activa o desactiva las guías automáticas al abrir pantallas nuevas por primera vez, o pulsa "Reiniciar guías de aprendizaje" para volver a habilitar todos los recorridos guiados.',
          tip:
              'Incluso con guías automáticas apagadas, el botón (i) de cada pantalla mantiene disponible el recorrido manual.',
          icon: Icons.explore_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_session_switch',
          targetKey: k.sessionSwitchKey,
          title: 'Cambiar de Negocio y Cerrar Sesión',
          description:
              'Usa "Cambiar de Negocio / Cerrar Sesión" para alternar entre distintos perfiles de negocio en este teléfono, registrar uno nuevo o cerrar la sesión activa limpiando carritos temporales.',
          tip:
              'Cada perfil conserva su propio inventario, clientes, finanzas e historial de ventas de forma independiente.',
          icon: Icons.swap_horiz_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_danger_zone',
          targetKey: k.dangerZoneKey,
          title: 'Zona de Peligro: Eliminar Perfil Actual',
          description:
              'Esta sección permite eliminar de forma permanente el perfil de negocio activo y todos sus registros locales del dispositivo tras superar un modal de confirmación de seguridad.',
          tip:
              'Antes de eliminar un perfil en uso, realiza un respaldo completo en "Respaldos y Seguridad" si podrías necesitar tus datos.',
          icon: Icons.warning_amber_rounded,
          borderRadius: 20.0,
        ),
      ],
    );
  }
}
