import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Historial de Ventas
class SalesHistoryTourKeys {
  final GlobalKey kpisKey;
  final GlobalKey searchBarKey;
  final GlobalKey filterChipsKey;
  final GlobalKey tabBarKey;
  final GlobalKey exportKey;

  SalesHistoryTourKeys({
    GlobalKey? kpisKey,
    GlobalKey? searchBarKey,
    GlobalKey? filterChipsKey,
    GlobalKey? tabBarKey,
    GlobalKey? exportKey,
  })  : kpisKey = kpisKey ?? GlobalKey(debugLabel: 'sales_tour_kpis'),
        searchBarKey = searchBarKey ?? GlobalKey(debugLabel: 'sales_tour_search'),
        filterChipsKey = filterChipsKey ?? GlobalKey(debugLabel: 'sales_tour_filters'),
        tabBarKey = tabBarKey ?? GlobalKey(debugLabel: 'sales_tour_tab_bar'),
        exportKey = exportKey ?? GlobalKey(debugLabel: 'sales_tour_export');
}

/// Configuración de la Guía Turística para Historial de Ventas, Reportes y Caja
class SalesHistoryTour {
  static final SalesHistoryTourKeys defaultKeys = SalesHistoryTourKeys();

  static ScreenTourConfig buildConfig({SalesHistoryTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'sales_history_screen',
      screenTitle: 'Historial de Ventas y Caja',
      welcomeSummary:
          'Supervisa tus ingresos diarios, cuadra caja por medio de pago, exporta reportes contables y consulta el detalle de cada comprobante.',
      icon: Icons.receipt_long_rounded,
      steps: [
        TourStep(
          id: 'step_kpis',
          targetKey: k.kpisKey,
          title: 'Métricas y Cuadre de Caja',
          description:
              'Revisa de inmediato el total vendido, ganancia neta y el desglose de ingresos por Efectivo, Yape/Plin, Transferencia o Fiado.',
          tip: 'Usa estas tarjetas para cuadrar tu dinero físico y digital al cierre de cada turno.',
          icon: Icons.payments_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_search',
          targetKey: k.searchBarKey,
          title: 'Búsqueda Rápida',
          description:
              'Ubica cualquier venta por número de ticket, nombre del cliente o producto vendido sin perder tiempo.',
          tip: 'Escribe el número de comprobante para ver el detalle de inmediato.',
          icon: Icons.search_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_filter_chips',
          targetKey: k.filterChipsKey,
          title: 'Filtros de Período y Pago',
          description:
              'Consulta las ventas de hoy, de la semana o personaliza un rango específico de fechas para auditoría o contabilidad.',
          tip: 'Combina filtros para ver, por ejemplo, solo las ventas de ayer cobradas con Yape.',
          icon: Icons.tune_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_tab_bar',
          targetKey: k.tabBarKey,
          title: 'Categorización de Ventas',
          description:
              'Navega entre ventas de Caja Rápida, Cotizaciones vendidas y operaciones anuladas o archivadas con reposición automática a stock.',
          tip: 'Anular una venta devuelve las unidades al inventario automáticamente.',
          icon: Icons.view_carousel_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_export',
          targetKey: k.exportKey,
          title: 'Exportación de Reportes',
          description:
              'Genera reportes financieros consolidados en PDF listos para imprimir o en hojas de cálculo Excel (CSV con UTF-8 BOM).',
          tip: 'Ideal para compartir tu balance mensual con tu contador o archivar auditorías.',
          icon: Icons.file_download_rounded,
          borderRadius: 24.0,
        ),
      ],
    );
  }
}
