import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [CommercialRadarScreen]
class CommercialRadarTourKeys {
  final locationPickerKey = GlobalKey(
    debugLabel: 'radar_tour_location_picker',
  );
  final operationalPulseKey = GlobalKey(
    debugLabel: 'radar_tour_operational_pulse',
  );
  final sourceStatusKey = GlobalKey(
    debugLabel: 'radar_tour_source_status',
  );
  final searchFiltersKey = GlobalKey(
    debugLabel: 'radar_tour_search_filters',
  );
  final signalCardKey = GlobalKey(
    debugLabel: 'radar_tour_signal_card',
  );
}

/// Configuración de la Guía Turística Interactiva para [CommercialRadarScreen]
class CommercialRadarTour {
  static final CommercialRadarTourKeys defaultKeys =
      CommercialRadarTourKeys();

  static ScreenTourConfig buildConfig({
    CommercialRadarTourKeys? keys,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'commercial_radar_screen',
      screenTitle: 'Radar Comercial IA',
      welcomeSummary:
          'Monitorea alertas reales de rutas, abastecimiento, leyes SUNAT y fechas comerciales según tu departamento, provincia o distrito.',
      icon: Icons.radar_rounded,
      steps: [
        TourStep(
          id: 'step_radar_location',
          targetKey: k.locationPickerKey,
          title: 'Selector Geográfico de 3 Niveles',
          description:
              'Configura Departamento, Provincia y Distrito/Localidad (incluyendo zonas alejadas) para activar la cascada automática Local -> Regional -> Nacional.',
          tip:
              'Toca la píldora de ubicación en cualquier momento para cambiar el enfoque territorial del radar.',
          icon: Icons.location_on_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_radar_pulse',
          targetKey: k.operationalPulseKey,
          title: 'Semáforo Operativo Comercial',
          description:
              'Evalúa de un vistazo el estado de Rutas/Fletes, Abastecimiento y los días que faltan para la próxima campaña comercial antes de cerrar pedidos.',
          tip:
              'Si detectas Precaución o Alerta en rutas o precios, anticípate reabasteciendo inventario clave.',
          icon: Icons.traffic_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_radar_source_mode',
          targetKey: k.sourceStatusKey,
          title: 'Indicador Honesto de Origen',
          description:
              'Diferencia al instante entre noticias reales en vivo (RSS + IA / análisis local), caché reciente y Guía Oficial de Referencia (Offline) en gob.pe.',
          tip:
              'Nunca simulamos conectividad: si trabajas sin internet verás el indicador de guía oficial o caché verificada.',
          icon: Icons.sensors_rounded,
          borderRadius: 10.0,
        ),
        TourStep(
          id: 'step_radar_filters',
          targetKey: k.searchFiltersKey,
          title: 'Buscador, Categorías y Guardadas',
          description:
              'Alterna entre Noticias del Día y Guardadas, busca temas específicos (SUNAT, rutas, clima) y filtra por Mi Región u otras categorías.',
          tip:
              'Usa las categorías Mi Región y Proveedores para aislar alertas relevantes para tus proveedores locales.',
          icon: Icons.filter_alt_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_radar_signal_card',
          targetKey: k.signalCardKey,
          title: 'Tarjetas de Señales y Acciones Directas',
          description:
              'Cada tarjeta resume el impacto en tu negocio y acciones recomendadas, permitiéndote abrir la fuente oficial verificada, guardar favoritos o compartir.',
          tip:
              'Guarda alertas regulatorias o logísticas importantes para revisarlas luego desde la pestaña Guardadas.',
          icon: Icons.bookmarks_rounded,
          borderRadius: 18.0,
        ),
      ],
    );
  }
}
