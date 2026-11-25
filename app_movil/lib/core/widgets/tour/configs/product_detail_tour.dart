import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [ProductDetailScreen]
class ProductDetailTourKeys {
  final variantSelectorKey = GlobalKey(
    debugLabel: 'prod_det_tour_variant_selector',
  );
  final financialDashboardKey = GlobalKey(
    debugLabel: 'prod_det_tour_financial_dashboard',
  );
  final stockAlertKey = GlobalKey(
    debugLabel: 'prod_det_tour_stock_alert',
  );
  final quickActionsKey = GlobalKey(
    debugLabel: 'prod_det_tour_quick_actions',
  );
  final auditEditActionsKey = GlobalKey(
    debugLabel: 'prod_det_tour_audit_edit_actions',
  );
}

/// Configuración de la Guía Turística Interactiva para [ProductDetailScreen]
class ProductDetailTour {
  static final ProductDetailTourKeys defaultKeys = ProductDetailTourKeys();

  static ScreenTourConfig buildConfig({
    ProductDetailTourKeys? keys,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'product_detail_screen',
      screenTitle: 'Detalle del Producto',
      welcomeSummary:
          'Alterna entre variantes, analiza costos y rentabilidad neta, vigila alertas de stock, ajusta precios o existencias al instante y audita el historial.',
      icon: Icons.inventory_rounded,
      steps: [
        TourStep(
          id: 'step_pd_variants',
          targetKey: k.variantSelectorKey,
          title: 'Selector de Variantes y Presentaciones',
          description:
              'Desliza y selecciona entre unidad, docena, caja o paquete para revisar en tiempo real su factor de conversión, código de barras y precio específico.',
          tip:
              'La estrella señala la presentación principal que aparece por defecto en catálogo y búsquedas.',
          icon: Icons.swap_horiz_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_pd_financial',
          targetKey: k.financialDashboardKey,
          title: 'Dashboard Financiero del Producto',
          description:
              'Visualiza el costo de la presentación, utilidad neta por venta, porcentaje de margen comercial, precio efectivo y valorizado real de tu inventario.',
          tip:
              'Si la variante usa stock compartido, el panel inferior indica el total de unidades base y el máximo formable.',
          icon: Icons.analytics_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'step_pd_stock_alert',
          targetKey: k.stockAlertKey,
          title: 'Alertas de Stock y Rotación',
          description:
              'Identifica alertas de stock bajo, agotado o cupo compartido restringido junto con los datos de rotación, unidad de venta y proveedor para reabastecer a tiempo.',
          tip:
              'Los productos nuevos mantienen un plazo de gracia de 7 días antes de emitir alertas preventivas mientras rotan.',
          icon: Icons.warning_amber_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_pd_quick_actions',
          targetKey: k.quickActionsKey,
          title: 'Acciones Rápidas (Stock, Precio y Oferta)',
          description:
              'Toca el precio de venta o el bloque de Stock Disponible para ajustar existencias, cambiar precios o configurar descuentos inteligentes sin abrir todo el formulario.',
          tip:
              'Todo ajuste rápido sincroniza al instante Catálogo, Buscador Rápido y Cotizaciones abiertas.',
          icon: Icons.flash_on_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_pd_audit_edit',
          targetKey: k.auditEditActionsKey,
          title: 'Auditoría de Movimientos (AuditTrail) y Edición',
          description:
              'Desde los iconos superiores abre el reloj de Auditoría/Kardex para ver cada cambio de precio o stock, o pulsa el lápiz para ir a la edición completa del producto.',
          tip:
              'También puedes tocar la foto superior para ampliarla a pantalla completa y verificar empaques.',
          icon: Icons.history_rounded,
          borderRadius: 14.0,
        ),
      ],
    );
  }
}
