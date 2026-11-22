import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Mesa de Trabajo / Cotizador Inteligente
class WorkbenchTourKeys {
  final GlobalKey kpisHeaderKey;
  final GlobalKey filterChipsKey;
  final GlobalKey exportReportsKey;
  final GlobalKey archivedListsKey;
  final GlobalKey newQuotationFabKey;

  WorkbenchTourKeys({
    GlobalKey? kpisHeaderKey,
    GlobalKey? filterChipsKey,
    GlobalKey? exportReportsKey,
    GlobalKey? archivedListsKey,
    GlobalKey? newQuotationFabKey,
  })  : kpisHeaderKey = kpisHeaderKey ?? GlobalKey(debugLabel: 'wb_tour_kpis_header'),
        filterChipsKey = filterChipsKey ?? GlobalKey(debugLabel: 'wb_tour_filter_chips'),
        exportReportsKey = exportReportsKey ?? GlobalKey(debugLabel: 'wb_tour_export_reports'),
        archivedListsKey = archivedListsKey ?? GlobalKey(debugLabel: 'wb_tour_archived_lists'),
        newQuotationFabKey = newQuotationFabKey ?? GlobalKey(debugLabel: 'wb_tour_new_quotation_fab');
}

/// Configuración de la Guía Turística para WorkbenchScreen
class WorkbenchTour {
  static final WorkbenchTourKeys defaultKeys = WorkbenchTourKeys();

  static ScreenTourConfig buildConfig({WorkbenchTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'workbench_screen',
      screenTitle: 'Mesa de Trabajo',
      welcomeSummary:
          'Arma listas escolares y pedidos complejos con asistencia de Inteligencia Artificial para emparejar útiles con tu inventario.',
      icon: Icons.checklist_rtl_rounded,
      steps: [
        TourStep(
          id: 'step_kpis_header',
          targetKey: k.kpisHeaderKey,
          title: 'Flujo de Trabajo de Cotizaciones',
          description:
              'Supervisa tus pedidos en tres etapas claras: "En Preparación" (borradores y listas en revisión), "Listas & Packs" (listas para entregar) y "Vendidas".',
          tip: 'Toca las métricas para enfocar rápidamente las cotizaciones que requieren tu atención.',
          icon: Icons.insights_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_filter_chips',
          targetKey: k.filterChipsKey,
          title: 'Filtros y Alertas de Stock',
          description:
              'Filtra listas por alertas de stock faltante, cotizaciones generadas con IA o pedidos armados manualmente.',
          tip: 'El chip de alertas te advierte si algún producto de la lista se quedó sin stock.',
          icon: Icons.filter_list_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_export_reports',
          targetKey: k.exportReportsKey,
          title: 'Proformas en PDF y Excel',
          description:
              'Genera documentos formales con el membrete y logotipo de tu negocio listos para compartir con tus clientes por WhatsApp o imprimir.',
          tip: 'Incluye subtotales, precios por paquete y datos de contacto de tu comercio.',
          icon: Icons.picture_as_pdf_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_archived_lists',
          targetKey: k.archivedListsKey,
          title: 'Listas Archivadas',
          description:
              'Consulta cotizaciones pasadas de años o temporadas anteriores para clonar útiles escolares recurrentes y ahorrar tiempo.',
          icon: Icons.inventory_2_outlined,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_new_quotation_fab',
          targetKey: k.newQuotationFabKey,
          title: 'Nueva Lista o Escaneo IA',
          description:
              'Crea una cotización manual o toma una fotografía a una lista escolar para que la IA la reconozca automáticamente y arme el presupuesto.',
          tip: 'Ahorra hasta un 80% del tiempo de atención en temporada escolar.',
          icon: Icons.add_circle_outline_rounded,
          borderRadius: 20.0,
        ),
      ],
    );
  }
}
