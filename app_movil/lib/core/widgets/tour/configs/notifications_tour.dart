import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [NotificationsScreen]
class NotificationsTourKeys {
  final GlobalKey filtersBarKey;
  final GlobalKey cardsFeedKey;
  final GlobalKey settingsButtonKey;
  final GlobalKey archiveActionsKey;

  NotificationsTourKeys({
    GlobalKey? filtersBarKey,
    GlobalKey? cardsFeedKey,
    GlobalKey? settingsButtonKey,
    GlobalKey? archiveActionsKey,
  }) : filtersBarKey =
           filtersBarKey ?? GlobalKey(debugLabel: 'notif_tour_filters_bar'),
       cardsFeedKey =
           cardsFeedKey ?? GlobalKey(debugLabel: 'notif_tour_cards_feed'),
       settingsButtonKey =
           settingsButtonKey ?? GlobalKey(debugLabel: 'notif_tour_settings_btn'),
       archiveActionsKey =
           archiveActionsKey ?? GlobalKey(debugLabel: 'notif_tour_archive_actions');
}

/// Guía Turística Interactiva completa para [NotificationsScreen] (4 pasos)
class NotificationsTour {
  static final NotificationsTourKeys defaultKeys = NotificationsTourKeys();

  static ScreenTourConfig buildConfig({NotificationsTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'notifications_screen',
      screenTitle: 'Centro de Notificaciones',
      welcomeSummary:
          'Controla cobranzas pendientes, vencimientos, alertas de inventario y cotizaciones desde una bandeja inteligente con filtros y acciones rápidas.',
      icon: Icons.notifications_active_rounded,
      steps: [
        TourStep(
          id: 'step_notif_filters',
          targetKey: k.filtersBarKey,
          title: 'Filtros por Estado, Categoría y Fecha',
          description:
              'Combina las pestañas superiores (Pendientes, Resueltas, Historial) con filtros de Cobranzas, Inventario, Cotizaciones y rango temporal.',
          tip: 'Usa el chip de fecha específica para auditar alertas generadas un día puntual.',
          icon: Icons.filter_list_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_notif_cards_feed',
          targetKey: k.cardsFeedKey,
          title: 'Tarjetas Interactivas y Estado al Día',
          description:
              'Desliza lateralmente o usa el menú de cada tarjeta para cobrar abonos, recordar por WhatsApp, resolver o silenciar; cuando no existan pendientes verás tu bandeja al día.',
          tip: 'Las cobranzas múltiples de un mismo cliente en mora crítica se agrupan en una tarjeta maestra.',
          icon: Icons.view_agenda_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_notif_settings',
          targetKey: k.settingsButtonKey,
          title: 'Silenciamiento y Preferencias de Canal',
          description:
              'Configura categorías activas, días de anticipación para cobranzas preventivas, agrupación inteligente y modo de gestos en tarjeta.',
          tip: 'Puedes activar acciones por deslizamiento directo si prefieres archivar o resolver con un gesto.',
          icon: Icons.tune_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'step_notif_archive_clear',
          targetKey: k.archiveActionsKey,
          title: 'Archivadas y Limpieza Rápida',
          description:
              'Consulta el historial de notificaciones archivadas en cualquier momento o marca todas las alertas sin leer como vistas de un toque.',
          tip: 'Mantener presiones largas en Historial también habilita selección múltiple para limpiar registros.',
          icon: Icons.inventory_2_outlined,
          borderRadius: 18.0,
        ),
      ],
    );
  }
}
