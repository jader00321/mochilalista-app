import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Licencia y Activación
class LicenseStatusTourKeys {
  final GlobalKey planStatusKey;
  final GlobalKey aiQuotaKey;
  final GlobalKey hardwareIdKey;
  final GlobalKey activationDualKey;
  final GlobalKey pricingCatalogKey;

  LicenseStatusTourKeys({
    GlobalKey? planStatusKey,
    GlobalKey? aiQuotaKey,
    GlobalKey? hardwareIdKey,
    GlobalKey? activationDualKey,
    GlobalKey? pricingCatalogKey,
  })  : planStatusKey = planStatusKey ?? GlobalKey(debugLabel: 'license_tour_plan_status'),
        aiQuotaKey = aiQuotaKey ?? GlobalKey(debugLabel: 'license_tour_ai_quota'),
        hardwareIdKey = hardwareIdKey ?? GlobalKey(debugLabel: 'license_tour_hardware_id'),
        activationDualKey = activationDualKey ?? GlobalKey(debugLabel: 'license_tour_activation_dual'),
        pricingCatalogKey = pricingCatalogKey ?? GlobalKey(debugLabel: 'license_tour_pricing_catalog');
}

/// Configuración de la Guía Turística para Licencia y Activación Comercial
class LicenseStatusTour {
  static final LicenseStatusTourKeys defaultKeys = LicenseStatusTourKeys();

  static ScreenTourConfig buildConfig({LicenseStatusTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'license_status_screen',
      screenTitle: 'Licencia y Activación Comercial',
      welcomeSummary:
          'Conoce el estado de tu licencia, consulta tus escaneos IA disponibles, activa códigos oficiales y comunícate directamente con soporte.',
      icon: Icons.verified_user_rounded,
      steps: [
        TourStep(
          id: 'step_plan_status',
          targetKey: k.planStatusKey,
          title: 'Estado del Plan y Vigencia',
          description:
              'Supervisa tu tipo de suscripción (Prueba Gratuita, Licencia Comercial o Acceso Perpetuo) y los días restantes de vigencia.',
          tip: 'Al renovar antes de que expire, los días restantes se acumulan automáticamente.',
          icon: Icons.card_membership_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_ai_quota',
          targetKey: k.aiQuotaKey,
          title: 'Saldo de Escaneos IA',
          description:
              'Consulta tu bolsa de escaneos inteligentes disponibles para digitalizar facturas y listas escolares con Inteligencia Artificial.',
          tip: 'Tus escaneos IA acumulados nunca vencen al renovar tu plan.',
          icon: Icons.auto_awesome_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_hardware_id',
          targetKey: k.hardwareIdKey,
          title: 'Identificador del Dispositivo (Hardware ID)',
          description:
              'Tu código único ML-XXXX que identifica esta instalación. Cópialo o compártelo con soporte al adquirir tu licencia oficial.',
          tip: 'Es un identificador anónimo de seguridad generado para la app (no es tu IMEI).',
          icon: Icons.fingerprint_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_activation_dual',
          targetKey: k.activationDualKey,
          title: 'Activación Dual de Licencia',
          description:
              'Canjea tu licencia escaneando el código QR oficial con la cámara, seleccionando una imagen de tu galería o pegando el código alfanumérico ML9-.',
          tip: 'Si recibiste el QR por WhatsApp, tómale captura y usa el botón de galería.',
          icon: Icons.qr_code_scanner_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_pricing_catalog',
          targetKey: k.pricingCatalogKey,
          title: 'Planes Oficiales y Soporte',
          description:
              'Explora nuestros planes comerciales oficiales y recargas en el acordeón inteligente, conoce sus beneficios al detalle y contacta en un toque al desarrollador oficial por WhatsApp.',
          tip: 'Toca cualquier plan para ver sus beneficios o pulsa "Pedir" para solicitarlo de inmediato.',
          icon: Icons.support_agent_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
