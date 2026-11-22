import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [BundleBuilderScreen]
class BundleBuilderTourKeys {
  final identityDurationKey = GlobalKey();
  final pricingSavingsKey = GlobalKey();
  final productSelectionKey = GlobalKey();
}

/// Configuración pedagógica de la Guía Turística para [BundleBuilderScreen]
class BundleBuilderTour {
  static ScreenTourConfig buildConfig({
    required BundleBuilderTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: 'bundle_builder_screen',
      screenTitle: 'Creador de Combos y Promociones',
      welcomeSummary:
          'Arma combos comerciales, paquetes escolares y ofertas flash con precios calculados para liquidar inventario o subir el ticket promedio.',
      icon: Icons.card_giftcard_rounded,
      steps: [
        TourStep(
          id: 'bundle_identity_duration',
          targetKey: keys.identityDurationKey,
          title: 'Modalidad y Vigencia de la Oferta',
          description:
              'Selecciona el formato comercial (Paquete Fusión, Oferta Flash, 2x1, Mayoreo o Pack Escolar) y define fechas límites si es una campaña estacional.',
          tip:
              'Las promociones con fecha de caducidad generan urgencia de compra durante la campaña escolar.',
          icon: Icons.local_offer_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'bundle_pricing_savings',
          targetKey: keys.pricingSavingsKey,
          title: 'Precio Especial y Rentabilidad',
          description:
              'Asigna el precio final del combo y verifica el semáforo de margen para confirmar que no estás vendiendo por debajo de tus costos de adquisición.',
          tip:
              'El porcentaje de ahorro se calcula automáticamente y se muestra en la tarjeta del catálogo.',
          icon: Icons.price_check_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'bundle_product_selection',
          targetKey: keys.productSelectionKey,
          title: 'Artículos y Cantidades del Combo',
          description:
              'Añade productos de tu almacén indicando la cantidad requerida de cada uno para componer la oferta empaquetada.',
          tip:
              'Agrupa productos estrella de alta demanda con artículos lentos para dinamizar tu stock inmovilizado.',
          icon: Icons.playlist_add_circle_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
