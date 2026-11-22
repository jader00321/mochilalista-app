import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Inventario y Catálogo
class InventoryTourKeys {
  final GlobalKey tabsKey;
  final GlobalKey invoiceAiKey;
  final GlobalKey searchFiltersKey;
  final GlobalKey newProductFabKey;

  InventoryTourKeys({
    GlobalKey? tabsKey,
    GlobalKey? invoiceAiKey,
    GlobalKey? searchFiltersKey,
    GlobalKey? newProductFabKey,
  })  : tabsKey = tabsKey ?? GlobalKey(debugLabel: 'inv_tour_tabs'),
        invoiceAiKey = invoiceAiKey ?? GlobalKey(debugLabel: 'inv_tour_invoice_ai'),
        searchFiltersKey = searchFiltersKey ?? GlobalKey(debugLabel: 'inv_tour_search_filters'),
        newProductFabKey = newProductFabKey ?? GlobalKey(debugLabel: 'inv_tour_new_prod_fab');
}

/// Configuración de la Guía Turística para InventoryScreen
class InventoryTour {
  static final InventoryTourKeys defaultKeys = InventoryTourKeys();

  static ScreenTourConfig buildConfig({
    InventoryTourKeys? keys,
    Future<void> Function()? onEnsureProductsTabActive,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'inventory_screen',
      screenTitle: 'Inventario y Catálogo',
      welcomeSummary:
          'Administra todo tu inventario: productos, categorías, marcas, proveedores y combos comerciales en un solo panel organizado.',
      icon: Icons.category_rounded,
      steps: [
        TourStep(
          id: 'step_tabs',
          targetKey: k.tabsKey,
          title: 'Pestañas de Catálogo',
          description:
              'Navega entre Productos, Ofertas y Combos, Categorías, Marcas y Proveedores para mantener tu negocio completamente estructurado.',
          tip: 'En cada pestaña puedes usar el botón de fusionar duplicados para limpiar registros repetidos.',
          icon: Icons.tab_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_invoice_ai',
          targetKey: k.invoiceAiKey,
          title: 'Facturas de Proveedor con IA',
          description:
              'Toma una foto a una factura física de compra y nuestra Inteligencia Artificial extraerá automáticamente cantidades, costos y productos nuevos.',
          tip: 'Ahorra horas de digitación manual al reabastecer tu mercadería.',
          icon: Icons.auto_awesome_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_search_filters',
          targetKey: k.searchFiltersKey,
          title: 'Buscador y Filtros Avanzados',
          description:
              'Encuentra artículos por nombre o filtra por bajo stock, productos agotados o rangos de precio con el panel lateral.',
          tip: 'Te ayuda a preparar tus pedidos a proveedores antes de quedarte sin existencias.',
          icon: Icons.filter_alt_outlined,
          borderRadius: 16.0,
          onBeforeStep: onEnsureProductsTabActive,
        ),
        TourStep(
          id: 'step_new_product_fab',
          targetKey: k.newProductFabKey,
          title: 'Crear Producto Nuevo',
          description:
              'Toca este botón para añadir nuevos productos, definir presentaciones de venta o importar masivamente tus artículos.',
          icon: Icons.add_circle_outline_rounded,
          borderRadius: 20.0,
          onBeforeStep: onEnsureProductsTabActive,
        ),
      ],
    );
  }
}
