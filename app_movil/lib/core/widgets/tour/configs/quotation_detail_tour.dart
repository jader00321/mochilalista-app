import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [QuotationDetailScreen]
class QuotationDetailTourKeys {
  final titleStatusKey = GlobalKey(
    debugLabel: 'quote_detail_tour_title_status',
  );
  final stockAlertOrItemsKey = GlobalKey(
    debugLabel: 'quote_detail_tour_stock_or_items',
  );
  final privacyAndEditKey = GlobalKey(
    debugLabel: 'quote_detail_tour_privacy_edit',
  );
  final totalsSummaryKey = GlobalKey(
    debugLabel: 'quote_detail_tour_totals_summary',
  );
  final outputActionsKey = GlobalKey(
    debugLabel: 'quote_detail_tour_output_actions',
  );
}

/// Configuración de la Guía Turística Interactiva para [QuotationDetailScreen]
class QuotationDetailTour {
  static final QuotationDetailTourKeys defaultKeys =
      QuotationDetailTourKeys();

  static ScreenTourConfig buildConfig({
    QuotationDetailTourKeys? keys,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'quotation_detail_screen',
      screenTitle: 'Detalle de Cotización',
      welcomeSummary:
          'Supervisa el estado de la lista, verifica alertas de stock, oculta tus costos frente al cliente y exporta en PDF, WhatsApp o convierte a venta.',
      icon: Icons.description_rounded,
      steps: [
        TourStep(
          id: 'step_quote_title_status',
          targetKey: k.titleStatusKey,
          title: 'Título Editable y Estado de la Cotización',
          description:
              'Toca el título superior para renombrar la cotización e identifica su estado actual (Pendiente, Listo, Vendida o Vencida) junto al cliente y colegio.',
          tip:
              'Desde el menú superior derecho también puedes actualizar el estado operativo o consultar historial.',
          icon: Icons.edit_note_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_quote_stock_alerts',
          targetKey: k.stockAlertOrItemsKey,
          title: 'Verificación de Stock y Alertas',
          description:
              'Antes de concretar la venta, el semáforo avisa si algún artículo no tiene stock suficiente, tiene conflicto compartido o cambió de precio, sugiriendo soluciones rápidas.',
          tip:
              'Cuando no existen quiebres de inventario, aquí revisas cada producto validado y sus unidades disponibles.',
          icon: Icons.fact_check_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_quote_privacy_edit',
          targetKey: k.privacyAndEditKey,
          title: 'Modo Privacidad (Ojo) y Edición',
          description:
              'Activa o desactiva el ojo superior para ocultar costos, márgenes y ganancia estimada cuando muestres la pantalla al cliente; además puedes editar ítems desde la barra inferior.',
          tip:
              'El modo privacidad se recuerda automáticamente entre vistas comerciales.',
          icon: Icons.visibility_off_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_quote_totals',
          targetKey: k.totalsSummaryKey,
          title: 'Resumen de Totales, Paquetes y Descuentos',
          description:
              'Consulta el total a pagar, cantidad de productos, ahorro en ofertas o paquetes aplicados, notas y datos del colegio o grado escolar.',
          tip:
              'Si la cotización incluye notas del cliente, toca la tarjeta naranja para expandir o contraer el detalle.',
          icon: Icons.calculate_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_quote_output_actions',
          targetKey: k.outputActionsKey,
          title: 'Acciones de Salida (PDF, WhatsApp y Vender)',
          description:
              'Edita la proforma, genera el PDF profesional, envíala por WhatsApp o pulsa VENDER / CORREGIR para convertir la cotización en venta descontando inventario.',
          tip:
              'Si la lista ya fue vendida, el botón principal te permite duplicarla como un nuevo borrador en un toque.',
          icon: Icons.point_of_sale_rounded,
          borderRadius: 20.0,
        ),
      ],
    );
  }
}
