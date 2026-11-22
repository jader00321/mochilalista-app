import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla Principal
class HomeScreenTourKeys {
  final GlobalKey headerKey;
  final GlobalKey omniSearchKey;
  final GlobalKey licenseAlertKey;
  final GlobalKey smartActionsKey;
  final GlobalKey activityKey;
  final GlobalKey bottomNavKey;

  HomeScreenTourKeys({
    GlobalKey? headerKey,
    GlobalKey? omniSearchKey,
    GlobalKey? licenseAlertKey,
    GlobalKey? smartActionsKey,
    GlobalKey? activityKey,
    GlobalKey? bottomNavKey,
  })  : headerKey = headerKey ?? GlobalKey(debugLabel: 'home_tour_header'),
        omniSearchKey = omniSearchKey ?? GlobalKey(debugLabel: 'home_tour_omnisearch'),
        licenseAlertKey = licenseAlertKey ?? GlobalKey(debugLabel: 'home_tour_license_alert'),
        smartActionsKey = smartActionsKey ?? GlobalKey(debugLabel: 'home_tour_smart_actions'),
        activityKey = activityKey ?? GlobalKey(debugLabel: 'home_tour_activity'),
        bottomNavKey = bottomNavKey ?? GlobalKey(debugLabel: 'home_tour_bottom_nav');
}

/// Configuración de la Guía Turística para la Pantalla Principal (HomeScreen)
class HomeScreenTour {
  static final HomeScreenTourKeys defaultKeys = HomeScreenTourKeys();

  // Getters para compatibilidad
  static GlobalKey get headerKey => defaultKeys.headerKey;
  static GlobalKey get omniSearchKey => defaultKeys.omniSearchKey;
  static GlobalKey get licenseAlertKey => defaultKeys.licenseAlertKey;
  static GlobalKey get smartActionsKey => defaultKeys.smartActionsKey;
  static GlobalKey get activityKey => defaultKeys.activityKey;
  static GlobalKey get bottomNavKey => defaultKeys.bottomNavKey;

  static ScreenTourConfig buildConfig({HomeScreenTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'home_screen',
      screenTitle: 'Pantalla de Inicio',
      welcomeSummary:
          'El centro neurálgico de tu negocio. Desde aquí supervisas tus ventas, buscas productos rápidamente y gestionas tus operaciones diarias.',
      icon: Icons.storefront_rounded,
      steps: [
        TourStep(
          id: 'step_header',
          targetKey: k.headerKey,
          title: 'Resumen del Negocio',
          description:
              'Visualiza de un vistazo el negocio activo, tus métricas de ventas del día y el acceso directo a notificaciones operativas.',
          tip: 'Toca el avatar o nombre del negocio para cambiar de espacio de trabajo rápidamente.',
          icon: Icons.business_center_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'step_omnisearch',
          targetKey: k.omniSearchKey,
          title: 'Búsqueda Universal OmniSearch',
          description:
              'Encuentra cualquier producto, precio o cliente al instante buscando por texto, código de barras o categoría.',
          tip: 'Toca el ícono de código de barras para escanear etiquetas con la cámara de tu celular.',
          icon: Icons.search_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_license',
          targetKey: k.licenseAlertKey,
          title: 'Licencia y Saldo IA',
          description:
              'Supervisa los días restantes de tu suscripción oficial y el saldo acumulativo de escaneos inteligentes con Inteligencia Artificial.',
          tip: 'Toca esta tarjeta para gestionar renovaciones, adquirir bonos IA o ver el catálogo comercial.',
          icon: Icons.verified_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_smart_actions',
          targetKey: k.smartActionsKey,
          title: 'Accesos Rápidos Operativos',
          description:
              'Atiende a tus clientes en segundos con botones directos para Venta Rápida, Inventario, Cotizaciones y Registro de Clientes.',
          tip: 'Botones amplios y táctiles optimizados para agilidad en mostrador.',
          icon: Icons.bolt_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'step_activity',
          targetKey: k.activityKey,
          title: 'Actividad y Ventas',
          description:
              'Revisa las ventas semanales y el estado de tus cotizaciones escolares para no perder ninguna oportunidad de venta.',
          icon: Icons.insights_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_bottom_nav',
          targetKey: k.bottomNavKey,
          title: 'Barra de Navegación',
          description:
              'Muévete con total fluidez entre Inicio, Catálogo, Cotizador Inteligente, Ventas y la Configuración de tu Perfil.',
          icon: Icons.navigation_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
