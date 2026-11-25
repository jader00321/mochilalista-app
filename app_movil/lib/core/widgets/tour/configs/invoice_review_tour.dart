import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [InvoiceReviewScreen]
class InvoiceReviewTourKeys {
  final GlobalKey splitWorkspaceKey;
  final GlobalKey metadataBtnKey;
  final GlobalKey itemsListKey;
  final GlobalKey continueBtnKey;

  InvoiceReviewTourKeys({
    GlobalKey? splitWorkspaceKey,
    GlobalKey? metadataBtnKey,
    GlobalKey? itemsListKey,
    GlobalKey? continueBtnKey,
  }) : splitWorkspaceKey =
           splitWorkspaceKey ?? GlobalKey(debugLabel: 'inv_rev_tour_split'),
       metadataBtnKey =
           metadataBtnKey ?? GlobalKey(debugLabel: 'inv_rev_tour_metadata'),
       itemsListKey =
           itemsListKey ?? GlobalKey(debugLabel: 'inv_rev_tour_items'),
       continueBtnKey =
           continueBtnKey ?? GlobalKey(debugLabel: 'inv_rev_tour_continue');
}

/// Guía Turística Interactiva completa para [InvoiceReviewScreen] (4 pasos)
class InvoiceReviewTour {
  static final InvoiceReviewTourKeys defaultKeys = InvoiceReviewTourKeys();

  static ScreenTourConfig buildConfig({InvoiceReviewTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'invoice_review_screen',
      screenTitle: 'Revisión de Factura IA',
      welcomeSummary:
          'Contrasta la fotografía original de compra contra los renglones extraídos por la IA antes de vincularlos con tu inventario.',
      icon: Icons.document_scanner_rounded,
      steps: [
        TourStep(
          id: 'step_rev_split_view',
          targetKey: k.splitWorkspaceKey,
          title: 'Visor Dividido con Zoom Táctil',
          description:
              'La pantalla se divide entre la foto de la factura arriba y la lista editable abajo. Arrastra la barra central ARRASTRAR para dar más altura a cualquiera de las dos áreas.',
          tip: 'Pellizca con dos dedos sobre la fotografía para verificar cifras o códigos pequeños.',
          icon: Icons.vertical_split_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_rev_metadata',
          targetKey: k.metadataBtnKey,
          title: 'Proveedor, RUC, Fecha y Total',
          description:
              'Pulsa Resumen en la barra superior para confirmar o corregir el proveedor detectado, su número RUC, la fecha de emisión y el monto total del comprobante.',
          tip: 'Junto a este botón también puedes inspeccionar la respuesta técnica de auditoría IA.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 10.0,
        ),
        TourStep(
          id: 'step_rev_edit_items',
          targetKey: k.itemsListKey,
          title: 'Edición de Cantidades, UMP y Costos',
          description:
              'Ajusta descripción, marca, código de barras, unidad de compra (UMP), unidades por lote y precio proveedor de cada ítem, o agrega renglones omitidos.',
          tip: 'Asegúrate de que las unidades por lote coincidan con lo que realmente venderás al detalle.',
          icon: Icons.edit_note_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_rev_continue_staging',
          targetKey: k.continueBtnKey,
          title: 'Confirmar y Clasificar en Inventario',
          description:
              'Cuando los montos y cantidades estén conformes, avanza hacia la etapa de clasificación para vincular productos existentes o crear fichas nuevas.',
          tip: 'Si falta algún producto en el detalle inicial, usa Añadir Fila Manualmente al pie de la lista.',
          icon: Icons.check_circle_outline_rounded,
          borderRadius: 12.0,
        ),
      ],
    );
  }
}
