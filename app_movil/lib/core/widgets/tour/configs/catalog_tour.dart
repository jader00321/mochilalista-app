import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves globales de anclaje para la Guía Turística Interactiva de Catálogo
class CatalogTourKeys {
  final GlobalKey searchFiltersKey;
  final GlobalKey offersSectionKey;
  final GlobalKey productGridKey;
  final GlobalKey cartActionKey;

  CatalogTourKeys({
    GlobalKey? searchFiltersKey,
    GlobalKey? offersSectionKey,
    GlobalKey? productGridKey,
    GlobalKey? cartActionKey,
  })  : searchFiltersKey = searchFiltersKey ?? GlobalKey(),
        offersSectionKey = offersSectionKey ?? GlobalKey(),
        productGridKey = productGridKey ?? GlobalKey(),
        cartActionKey = cartActionKey ?? GlobalKey();
}

/// Configuración de la Guía Turística Interactiva para Catálogo Visual de Productos
class CatalogTour {
  static const String screenId = 'catalog_screen';

  static ScreenTourConfig buildConfig({
    required CatalogTourKeys keys,
    Future<void> Function()? onExpandOffers,
    Future<void> Function()? onCollapseOffers,
    Future<void> Function()? onExpandBottomMenu,
    Future<void> Function()? onCollapseBottomMenu,
  }) {
    return ScreenTourConfig(
      screenId: screenId,
      screenTitle: 'Catálogo Visual de Ventas',
      welcomeSummary:
          'Explora tus productos en una vitrina comercial ágil. Agrega productos al carrito, revisa promociones y pasa a cotizar o cobrar en mostrador con un solo toque.',
      icon: Icons.menu_book_rounded,
      steps: [
        TourStep(
          id: 'step_search_filters',
          targetKey: keys.searchFiltersKey,
          title: 'Buscador y Filtros en Vivo',
          description:
              'Filtra rápidamente por texto, categorías o abre el panel de filtros avanzados para ubicar cualquier artículo en segundos.',
          tip:
              'Usa el botón de Modo Tienda en la barra superior para ocultar costos y datos privados al mostrar la pantalla a tus clientes.',
          icon: Icons.search_rounded,
        ),
        TourStep(
          id: 'step_offers_section',
          targetKey: keys.offersSectionKey,
          title: 'Ofertas y Paquetes Comerciales',
          description:
              'Revisa tus combos activos, promociones flash o precios por volumen disponibles para incentivar la compra de tus clientes.',
          tip:
              'Los combos descuentan automáticamente las existencias de todos sus productos componentes.',
          icon: Icons.local_offer_outlined,
          onBeforeStep: onExpandOffers,
          onAfterStep: onCollapseOffers,
        ),
        TourStep(
          id: 'step_product_grid',
          targetKey: keys.productGridKey,
          title: 'Cuadrícula de Productos y Stock',
          description:
              'Visualiza cada artículo con su precio de venta, disponibilidad y variantes. Toca una tarjeta para ver opciones y agregarlo a tu carrito.',
          tip:
              'Los productos sin stock o con alertas quedan destacados visualmente para evitar ventas sin existencia.',
          icon: Icons.grid_view_rounded,
        ),
        TourStep(
          id: 'step_cart_action',
          targetKey: keys.cartActionKey,
          title: 'Carrito y Acciones Rápidas',
          description:
              'Accede al resumen de los productos seleccionados y pásalos directamente a la Caja Rápida para cobrar o a Cotización Manual.',
          tip:
              'Tu carrito conserva los productos mientras navegas por otras secciones de la app.',
          icon: Icons.shopping_cart_checkout_rounded,
          onBeforeStep: onExpandBottomMenu,
          onAfterStep: onCollapseBottomMenu,
        ),
      ],
    );
  }
}
