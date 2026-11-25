import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor completo de claves por pestaña para Gestión de Negocio (5 pestañas)
class InventoryTabTourKeys {
  // Tab 0: PRODUCTOS
  final GlobalKey tabsKey;
  final GlobalKey invoiceAiKey;
  final GlobalKey searchFiltersKey;
  final GlobalKey productCardKey;
  final GlobalKey newProductFabKey;

  // Tab 1: OFERTAS / BUNDLES
  final GlobalKey offersInsightsKey;
  final GlobalKey offersNewButtonKey;
  final GlobalKey offersListKey;

  // Tab 2: CATEGORÍAS
  final GlobalKey categoriesToolbarKey;
  final GlobalKey categoriesSuggestedKey;
  final GlobalKey categoriesListKey;
  final GlobalKey categoriesFabKey;

  // Tab 3: MARCAS
  final GlobalKey brandsToolbarKey;
  final GlobalKey brandsListKey;
  final GlobalKey brandsFabKey;

  // Tab 4: PROVEEDORES
  final GlobalKey providersToolbarKey;
  final GlobalKey providersListKey;
  final GlobalKey providersFabKey;

  InventoryTabTourKeys({
    GlobalKey? tabsKey,
    GlobalKey? invoiceAiKey,
    GlobalKey? searchFiltersKey,
    GlobalKey? productCardKey,
    GlobalKey? newProductFabKey,
    GlobalKey? offersInsightsKey,
    GlobalKey? offersNewButtonKey,
    GlobalKey? offersListKey,
    GlobalKey? categoriesToolbarKey,
    GlobalKey? categoriesSuggestedKey,
    GlobalKey? categoriesListKey,
    GlobalKey? categoriesFabKey,
    GlobalKey? brandsToolbarKey,
    GlobalKey? brandsListKey,
    GlobalKey? brandsFabKey,
    GlobalKey? providersToolbarKey,
    GlobalKey? providersListKey,
    GlobalKey? providersFabKey,
  }) : tabsKey = tabsKey ?? GlobalKey(debugLabel: 'inv_tour_tabs'),
       invoiceAiKey =
           invoiceAiKey ?? GlobalKey(debugLabel: 'inv_tour_invoice_ai'),
       searchFiltersKey =
           searchFiltersKey ?? GlobalKey(debugLabel: 'inv_tour_search_filters'),
       productCardKey =
           productCardKey ?? GlobalKey(debugLabel: 'inv_tour_product_card'),
       newProductFabKey =
           newProductFabKey ?? GlobalKey(debugLabel: 'inv_tour_new_prod_fab'),
       offersInsightsKey =
           offersInsightsKey ??
           GlobalKey(debugLabel: 'inv_tour_offers_insights'),
       offersNewButtonKey =
           offersNewButtonKey ??
           GlobalKey(debugLabel: 'inv_tour_offers_new_btn'),
       offersListKey =
           offersListKey ?? GlobalKey(debugLabel: 'inv_tour_offers_list'),
       categoriesToolbarKey =
           categoriesToolbarKey ??
           GlobalKey(debugLabel: 'inv_tour_cat_toolbar'),
       categoriesSuggestedKey =
           categoriesSuggestedKey ??
           GlobalKey(debugLabel: 'inv_tour_cat_suggested'),
       categoriesListKey =
           categoriesListKey ?? GlobalKey(debugLabel: 'inv_tour_cat_list'),
       categoriesFabKey =
           categoriesFabKey ?? GlobalKey(debugLabel: 'inv_tour_cat_fab'),
       brandsToolbarKey =
           brandsToolbarKey ?? GlobalKey(debugLabel: 'inv_tour_brand_toolbar'),
       brandsListKey =
           brandsListKey ?? GlobalKey(debugLabel: 'inv_tour_brand_list'),
       brandsFabKey =
           brandsFabKey ?? GlobalKey(debugLabel: 'inv_tour_brand_fab'),
       providersToolbarKey =
           providersToolbarKey ??
           GlobalKey(debugLabel: 'inv_tour_prov_toolbar'),
       providersListKey =
           providersListKey ?? GlobalKey(debugLabel: 'inv_tour_prov_list'),
       providersFabKey =
           providersFabKey ?? GlobalKey(debugLabel: 'inv_tour_prov_fab');
}

/// Alias retrocompatible heredado para InventoryScreen y suites previas
class InventoryTourKeys extends InventoryTabTourKeys {
  InventoryTourKeys({
    super.tabsKey,
    super.invoiceAiKey,
    super.searchFiltersKey,
    super.productCardKey,
    super.newProductFabKey,
    super.offersInsightsKey,
    super.offersNewButtonKey,
    super.offersListKey,
    super.categoriesToolbarKey,
    super.categoriesSuggestedKey,
    super.categoriesListKey,
    super.categoriesFabKey,
    super.brandsToolbarKey,
    super.brandsListKey,
    super.brandsFabKey,
    super.providersToolbarKey,
    super.providersListKey,
    super.providersFabKey,
  });
}

/// Configuración de Guías Turísticas dedicadas por pestaña para Gestión de Negocio
class InventoryTour {
  static final InventoryTourKeys defaultKeys = InventoryTourKeys();

  static ScreenTourConfig buildConfig({
    InventoryTourKeys? keys,
    Future<void> Function()? onEnsureProductsTabActive,
  }) {
    return buildConfigForTab(
      tabIndex: 0,
      keys: keys ?? defaultKeys,
      onEnsureProductsTabActive: onEnsureProductsTabActive,
    );
  }

  /// Despacha la configuración interactiva específica para la pestaña activa [tabIndex] (0..4)
  static ScreenTourConfig buildConfigForTab({
    required int tabIndex,
    InventoryTabTourKeys? keys,
    Future<void> Function()? onEnsureProductsTabActive,
    Future<void> Function()? onExpandOffersInsights,
    Future<void> Function()? onRestoreOffersInsights,
  }) {
    final k = keys ?? defaultKeys;

    switch (tabIndex) {
      case 1:
        return ScreenTourConfig(
          screenId: 'inventory_offers_tab',
          screenTitle: 'Ofertas y Bundles',
          welcomeSummary:
              'Detecta artículos de lenta rotación y crea combos o liquidaciones estratégicas sin perder rentabilidad.',
          icon: Icons.local_offer_rounded,
          onCancel: onRestoreOffersInsights,
          onDismiss: onRestoreOffersInsights,
          steps: [
            TourStep(
              id: 'step_offers_insights',
              targetKey: k.offersInsightsKey,
              title: 'Insights y Sugerencias Inteligentes',
              description:
                  'Analiza automáticamente productos con baja rotación para proponerte paquetes fusión o liquidaciones rápidas.',
              tip: 'Toca la cabecera para expandir o contraer estas recomendaciones en cualquier momento.',
              icon: Icons.lightbulb_outline_rounded,
              borderRadius: 14.0,
              onBeforeStep: onExpandOffersInsights,
              onAfterStep: onRestoreOffersInsights,
            ),
            TourStep(
              id: 'step_offers_new_btn',
              targetKey: k.offersNewButtonKey,
              title: 'Crear Nuevo Paquete u Oferta',
              description:
                  'Abre el constructor de promociones para armar ofertas Flash, Liquidez, 2x1, Mayoreo o combos Escolares.',
              tip: 'El stock del paquete se calcula automáticamente según la disponibilidad real de sus componentes.',
              icon: Icons.add_box_rounded,
              borderRadius: 12.0,
            ),
            TourStep(
              id: 'step_offers_list',
              targetKey: k.offersListKey,
              title: 'Paquetes Activos y Vigencia',
              description:
                  'Supervisa tus promociones creadas, su margen de ganancia, unidades disponibles para armar y fecha límite.',
              tip: 'Toca cualquier paquete para editarlo o compártelo por WhatsApp en un toque.',
              icon: Icons.discount_outlined,
              borderRadius: 18.0,
            ),
          ],
        );

      case 2:
        return ScreenTourConfig(
          screenId: 'inventory_categories_tab',
          screenTitle: 'Categorías de Catálogo',
          welcomeSummary:
              'Estructura tu catálogo por líneas de producto con ayuda automática de IA y detección de duplicados.',
          icon: Icons.category_outlined,
          steps: [
            TourStep(
              id: 'step_cat_toolbar',
              targetKey: k.categoriesToolbarKey,
              title: 'Orden, Auto-categorizar IA y Duplicados',
              description:
                  'Ordena tus categorías alfabéticamente o por cantidad de artículos, clasifica productos con IA y fusiona duplicados.',
              tip: 'Usa Detectar Duplicados si notas categorías parecidas creadas por error.',
              icon: Icons.auto_awesome_rounded,
              borderRadius: 14.0,
            ),
            TourStep(
              id: 'step_cat_suggested',
              targetKey: k.categoriesSuggestedKey,
              title: 'Categorías Sugeridas en 1 Toque',
              description:
                  'Cuando estás empezando, toca cualquiera de las sugerencias para crear categorías base listas para usar.',
              tip: 'Puedes ocultar este panel con el botón de cerrar si prefieres solo categorías propias.',
              icon: Icons.lightbulb_outline_rounded,
              borderRadius: 16.0,
            ),
            TourStep(
              id: 'step_cat_list_modal',
              targetKey: k.categoriesListKey,
              title: 'Detalle, Edición y Conteo',
              description:
                  'Cada tarjeta muestra cuántos productos tiene vinculados. Toca una categoría para ver su ficha detallada, editarla o activarla.',
              icon: Icons.list_alt_rounded,
              borderRadius: 16.0,
            ),
            TourStep(
              id: 'step_cat_fab',
              targetKey: k.categoriesFabKey,
              title: 'Crear Nueva Categoría',
              description:
                  'Pulsa este botón para añadir una categoría personalizada con validación automática anti-duplicados.',
              icon: Icons.add_circle_outline_rounded,
              borderRadius: 18.0,
            ),
          ],
        );

      case 3:
        return ScreenTourConfig(
          screenId: 'inventory_brands_tab',
          screenTitle: 'Marcas de Productos',
          welcomeSummary:
              'Administra las marcas oficiales de tu inventario, unifica nombres similares y revisa cuántos productos pertenecen a cada una.',
          icon: Icons.branding_watermark_outlined,
          steps: [
            TourStep(
              id: 'step_brand_toolbar',
              targetKey: k.brandsToolbarKey,
              title: 'Herramientas de Marcas y Duplicados',
              description:
                  'Ordena tus marcas y utiliza Detectar Duplicados para fusionar marcas repetidas sin perder los productos vinculados.',
              tip: 'Al fusionar duplicados todos sus productos pasan automáticamente a la marca principal.',
              icon: Icons.find_replace_rounded,
              borderRadius: 14.0,
            ),
            TourStep(
              id: 'step_brand_list',
              targetKey: k.brandsListKey,
              title: 'Fichas y Modal de Detalle',
              description:
                  'Toca cualquier marca para abrir su ficha completa, revisar productos asociados, editar el nombre o suspenderla.',
              icon: Icons.branding_watermark_rounded,
              borderRadius: 16.0,
            ),
            TourStep(
              id: 'step_brand_fab',
              targetKey: k.brandsFabKey,
              title: 'Registrar Nueva Marca',
              description:
                  'Abre el formulario rápido de alta de marca con alerta preventiva si existe una similitud previa.',
              icon: Icons.add_circle_outline_rounded,
              borderRadius: 18.0,
            ),
          ],
        );

      case 4:
        return ScreenTourConfig(
          screenId: 'inventory_providers_tab',
          screenTitle: 'Proveedores y Compras',
          welcomeSummary:
              'Centraliza a tus distribuidores con RUC, teléfono y correo, detecta duplicados y consulta sus productos vinculados.',
          icon: Icons.local_shipping_outlined,
          steps: [
            TourStep(
              id: 'step_prov_toolbar',
              targetKey: k.providersToolbarKey,
              title: 'Orden y Limpieza de Proveedores',
              description:
                  'Ordena tu directorio de proveedores y unifica duplicados por RUC o nombre comercial sin afectar tu historial.',
              icon: Icons.find_replace_rounded,
              borderRadius: 14.0,
            ),
            TourStep(
              id: 'step_prov_list',
              targetKey: k.providersListKey,
              title: 'Ficha Detallada del Proveedor',
              description:
                  'Toca un proveedor para abrir su modal detalle con RUC, contacto, productos enlazados y edición rápida.',
              tip: 'Mantener el RUC completo mejora el reconocimiento automático al escanear facturas con IA.',
              icon: Icons.business_rounded,
              borderRadius: 16.0,
            ),
            TourStep(
              id: 'step_prov_fab',
              targetKey: k.providersFabKey,
              title: 'Registrar Nuevo Proveedor',
              description:
                  'Crea fichas nuevas de distribuidores validando automáticamente que no repitas RUC ni razón social.',
              icon: Icons.add_circle_outline_rounded,
              borderRadius: 18.0,
            ),
          ],
        );

      case 0:
      default:
        return ScreenTourConfig(
          screenId: 'inventory_screen',
          screenTitle: 'Gestión de Negocio',
          welcomeSummary:
              'Administra todo tu inventario: productos, categorías, marcas, proveedores y combos comerciales en un solo panel organizado.',
          icon: Icons.category_rounded,
          steps: [
            TourStep(
              id: 'step_tabs',
              targetKey: k.tabsKey,
              title: 'Pestañas de Gestión de Negocio',
              description:
                  'Navega entre Productos, Ofertas / Bundles, Categorías, Marcas y Proveedores. Al abrir el botón de ayuda en cada pestaña verás su guía dedicada.',
              tip: 'Cambia de pestaña y pulsa el ícono de información para ver la guía específica de esa sección.',
              icon: Icons.tab_rounded,
              borderRadius: 14.0,
            ),
            TourStep(
              id: 'step_invoice_ai',
              targetKey: k.invoiceAiKey,
              title: 'Facturas de Proveedor con IA',
              description:
                  'Accede al historial inteligente de compras y facturas escaneadas para ingresar mercadería y costos en segundos.',
              tip: 'Ahorra horas de digitación manual al reabastecer tu mercadería.',
              icon: Icons.auto_awesome_rounded,
              borderRadius: 20.0,
            ),
            TourStep(
              id: 'step_search_filters',
              targetKey: k.searchFiltersKey,
              title: 'Buscador y Filtros Avanzados',
              description:
                  'Encuentra artículos por nombre, escanea código de barras, alterna vistas (lista, grilla o compacta) y filtra por bajo stock o agotados.',
              tip: 'Te ayuda a preparar tus pedidos a proveedores antes de quedarte sin existencias.',
              icon: Icons.filter_alt_outlined,
              borderRadius: 16.0,
              onBeforeStep: onEnsureProductsTabActive,
            ),
            TourStep(
              id: 'step_product_card',
              targetKey: k.productCardKey,
              title: 'Tarjetas de Producto y Stock',
              description:
                  'Revisa stock vendible (propio o compartido), costo y precio al instante, o toca un producto para ver estadísticas, movimientos y edición.',
              tip: 'Toca el precio o stock de la tarjeta para ajustarlos rápidamente sin salir del catálogo.',
              icon: Icons.inventory_2_outlined,
              borderRadius: 16.0,
              onBeforeStep: onEnsureProductsTabActive,
            ),
            TourStep(
              id: 'step_new_product_fab',
              targetKey: k.newProductFabKey,
              title: 'Crear o Importar Productos',
              description:
                  'Despliega el menú rápido para registrar por Ingreso Manual, Auto-categorizar con IA, Escanear Código o Escanear Factura con IA.',
              icon: Icons.add_circle_outline_rounded,
              borderRadius: 20.0,
              onBeforeStep: onEnsureProductsTabActive,
            ),
          ],
        );
    }
  }
}
