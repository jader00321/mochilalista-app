import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Clientes (CRM)
class ClientTrackingTourKeys {
  final GlobalKey searchBarKey;
  final GlobalKey filterBarKey;
  final GlobalKey clientListKey;
  final GlobalKey addClientKey;
  final GlobalKey loyaltyKey;

  ClientTrackingTourKeys({
    GlobalKey? searchBarKey,
    GlobalKey? filterBarKey,
    GlobalKey? clientListKey,
    GlobalKey? addClientKey,
    GlobalKey? loyaltyKey,
  })  : searchBarKey = searchBarKey ?? GlobalKey(debugLabel: 'client_tour_search_bar'),
        filterBarKey = filterBarKey ?? GlobalKey(debugLabel: 'client_tour_filter_bar'),
        clientListKey = clientListKey ?? GlobalKey(debugLabel: 'client_tour_client_list'),
        addClientKey = addClientKey ?? GlobalKey(debugLabel: 'client_tour_add_client'),
        loyaltyKey = loyaltyKey ?? GlobalKey(debugLabel: 'client_tour_loyalty');
}

/// Configuración de la Guía Turística para Clientes y Créditos CRM
class ClientTrackingTour {
  static final ClientTrackingTourKeys defaultKeys = ClientTrackingTourKeys();

  static ScreenTourConfig buildConfig({ClientTrackingTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'client_tracking_screen',
      screenTitle: 'Clientes y Créditos CRM',
      welcomeSummary:
          'Gestiona tu cartera de clientes, supervisa cuentas por cobrar, envía recordatorios por WhatsApp y registra nuevos clientes en segundos.',
      icon: Icons.people_alt_rounded,
      steps: [
        TourStep(
          id: 'step_search',
          targetKey: k.searchBarKey,
          title: 'Buscador de Clientes',
          description:
              'Encuentra clientes rápidamente por nombre, teléfono o DNI para consultar su saldo o registrar una nueva venta a crédito.',
          tip: 'Escribe parte del nombre o teléfono para filtrar la lista al instante.',
          icon: Icons.search_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_filters',
          targetKey: k.filterBarKey,
          title: 'Filtros y Cuentas por Cobrar',
          description:
              'Identifica al instante qué clientes tienen deuda pendiente ("Con Deuda"), entregas por realizar o filtra por nivel de confianza.',
          tip: 'Toca "Con Deuda" para priorizar tus cobros y recordatorios del día.',
          icon: Icons.filter_list_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_client_list',
          targetKey: k.clientListKey,
          title: 'Directorio y Gestión de Abonos',
          description:
              'Explora tu lista de clientes. Toca cualquier cliente para ver su estado de cuenta detallado, registrar amortizaciones (abonos) o editar su límite de crédito.',
          tip: 'Registra abonos en tiempo real para mantener el saldo actualizado.',
          icon: Icons.badge_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_add_client',
          targetKey: k.addClientKey,
          title: 'Registro de Nuevo Cliente',
          description:
              'Registra un nuevo contacto con nombre, teléfono y documento en pocos segundos para asociarlo a tus ventas o cotizaciones.',
          tip: 'Puedes registrar clientes también desde el Punto de Venta.',
          icon: Icons.person_add_rounded,
          borderRadius: 24.0,
        ),
        TourStep(
          id: 'step_loyalty',
          targetKey: k.loyaltyKey,
          title: 'Fidelización y Premios',
          description:
              'Recompensa a tus mejores clientes acumulando puntos por cada compra y gestionando premios o descuentos de fidelidad.',
          tip: 'Fidelizar a tus clientes habituales aumenta tus ventas recurrentes.',
          icon: Icons.military_tech_rounded,
          borderRadius: 24.0,
        ),
      ],
    );
  }
}
