import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [SaleHistoryDetailScreen]
class SaleHistoryDetailTourKeys {
  final headerSummaryKey = GlobalKey(
    debugLabel: 'sale_hist_tour_header_summary',
  );
  final itemsDetailKey = GlobalKey(
    debugLabel: 'sale_hist_tour_items_detail',
  );
  final footerEmitKey = GlobalKey(
    debugLabel: 'sale_hist_tour_footer_emit',
  );
  final cancelMenuKey = GlobalKey(
    debugLabel: 'sale_hist_tour_cancel_menu',
  );
}

/// Configuración de la Guía Turística Interactiva para [SaleHistoryDetailScreen]
class SaleHistoryDetailTour {
  static final SaleHistoryDetailTourKeys defaultKeys =
      SaleHistoryDetailTourKeys();

  static ScreenTourConfig buildConfig({
    SaleHistoryDetailTourKeys? keys,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'sale_history_detail_screen',
      screenTitle: 'Detalle de Venta y Comprobante',
      welcomeSummary:
          'Revisa el resumen contable del comprobante, el detalle de productos vendidos, emite PDF o ticket térmico y gestiona anulaciones atómicas seguras.',
      icon: Icons.receipt_long_rounded,
      steps: [
        TourStep(
          id: 'step_shd_header_summary',
          targetKey: k.headerSummaryKey,
          title: 'Resumen del Comprobante y Origen',
          description:
              'Muestra el número secuencial, canal de origen (Caja Rápida, Lista IA, Manual, Web o Préstamo), fecha, cliente asociado y monto total o estado anulado.',
          tip:
              'Justo debajo también puedes consultar y editar notas internas o del cliente sin alterar el saldo contable.',
          icon: Icons.receipt_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_shd_items_detail',
          targetKey: k.itemsDetailKey,
          title: 'Detalle de Ítems, Precios y Márgenes',
          description:
              'Inspecciona cada artículo entregado con su marca, presentación vendida, cantidad, descuentos aplicados y subtotal calculado con utilidad real.',
          tip:
              'En operaciones a crédito o préstamos, verás además el desglose financiero de pagos y saldo pendiente.',
          icon: Icons.inventory_2_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_shd_footer_emit',
          targetKey: k.footerEmitKey,
          title: 'Emisión y Envío (Impresora Térmica, PDF y WhatsApp)',
          description:
              'Genera la vista previa PDF (lista para reimprimir ticket Bluetooth), comparte el comprobante por WhatsApp, vuelve a vender o registra cobros pendientes.',
          tip:
              'Desde la barra de opciones también puedes duplicar listas asociadas hacia un nuevo pedido en segundos.',
          icon: Icons.print_rounded,
          borderRadius: 20.0,
        ),
        TourStep(
          id: 'step_shd_cancel_menu',
          targetKey: k.cancelMenuKey,
          title: 'Anulación Atómica y Seguridad Contable',
          description:
              'Desde el menú de tres puntos superior puedes anular (o restaurar) la operación seleccionando el motivo, revirtiendo el stock al inventario con trazabilidad intacta.',
          tip:
              'Toda anulación queda registrada como operación auditada sin destruir los comprobantes emitidos.',
          icon: Icons.security_rounded,
          borderRadius: 12.0,
        ),
      ],
    );
  }
}
