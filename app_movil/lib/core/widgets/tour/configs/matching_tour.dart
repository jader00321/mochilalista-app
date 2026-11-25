import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [MatchingScreen]
class MatchingTourKeys {
  final GlobalKey clientAccordionKey;
  final GlobalKey matchedItemsKey;
  final GlobalKey manualAddKey;
  final GlobalKey quoteNotesAccordionKey;
  final GlobalKey bottomBarKey;

  MatchingTourKeys({
    GlobalKey? clientAccordionKey,
    GlobalKey? matchedItemsKey,
    GlobalKey? manualAddKey,
    GlobalKey? quoteNotesAccordionKey,
    GlobalKey? bottomBarKey,
  }) : clientAccordionKey =
           clientAccordionKey ?? GlobalKey(debugLabel: 'match_tour_client_acc'),
       matchedItemsKey =
           matchedItemsKey ?? GlobalKey(debugLabel: 'match_tour_items_area'),
       manualAddKey =
           manualAddKey ?? GlobalKey(debugLabel: 'match_tour_manual_add'),
       quoteNotesAccordionKey =
           quoteNotesAccordionKey ?? GlobalKey(debugLabel: 'match_tour_quote_acc'),
       bottomBarKey =
           bottomBarKey ?? GlobalKey(debugLabel: 'match_tour_bottom_bar');
}

/// Guía Turística Interactiva completa para [MatchingScreen] (5 pasos)
class MatchingTour {
  static final MatchingTourKeys defaultKeys = MatchingTourKeys();

  static ScreenTourConfig buildConfig({
    MatchingTourKeys? keys,
    Future<void> Function()? onExpandClientPanel,
    Future<void> Function()? onRestoreClientPanel,
    Future<void> Function()? onExpandQuoteData,
    Future<void> Function()? onRestoreQuoteData,
  }) {
    final k = keys ?? defaultKeys;

    Future<void> restoreAll() async {
      await onRestoreClientPanel?.call();
      await onRestoreQuoteData?.call();
    }

    return ScreenTourConfig(
      screenId: 'matching_screen',
      screenTitle: 'Cotización Inteligente IA',
      welcomeSummary:
          'Concilia los útiles escaneados contra tu catálogo real, revisa equivalentes y stock compartido, personaliza cliente y cierra la proforma o venta.',
      icon: Icons.auto_fix_high_rounded,
      onCancel: restoreAll,
      onDismiss: restoreAll,
      steps: [
        TourStep(
          id: 'step_match_client_school',
          targetKey: k.clientAccordionKey,
          title: 'Cliente, Colegio y Modo Comercial',
          description:
              'Despliega este encabezado para alternar entre modo General, Mayorista o Escolar, vincular un cliente CRM e indicar institución o grado.',
          tip: 'El nombre de la cotización se sincroniza automáticamente según el cliente o colegio elegido.',
          icon: Icons.school_outlined,
          borderRadius: 16.0,
          onBeforeStep: onExpandClientPanel,
          onAfterStep: onRestoreClientPanel,
        ),
        TourStep(
          id: 'step_match_ai_items',
          targetKey: k.matchedItemsKey,
          title: 'Emparejamiento IA, Equivalentes y Stock',
          description:
              'Revisa cada producto detectado y su vínculo con inventario: toca una fila para ajustar cantidad o presentación, comparar equivalentes sugeridos o reemplazar manualmente.',
          tip: 'Las alertas de stock compartido o paquetes en oferta aparecen destacadas automáticamente.',
          icon: Icons.fact_check_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_match_manual_search',
          targetKey: k.manualAddKey,
          title: 'Búsqueda Rápida de Faltantes',
          description:
              'Si la lista trajo artículos adicionales o necesitas agregar ítems fuera del escaneo, añade una fila manual y búscala en tu tienda en segundos.',
          tip: 'También puedes usar este botón para completar productos no identificados a primera lectura.',
          icon: Icons.add_shopping_cart_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_match_quote_notes',
          targetKey: k.quoteNotesAccordionKey,
          title: 'Título Editable y Notas del Pedido',
          description:
              'Abre este bloque para ajustar el título de la cotización (con restauración automática si la editas) y redactar indicaciones u observaciones internas.',
          tip: 'Las notas aquí escritas sirven de referencia operativa al retomar la proforma en Mesa de Trabajo.',
          icon: Icons.sticky_note_2_outlined,
          borderRadius: 16.0,
          onBeforeStep: onExpandQuoteData,
          onAfterStep: onRestoreQuoteData,
        ),
        TourStep(
          id: 'step_match_bottom_bar',
          targetKey: k.bottomBarKey,
          title: 'Total, Ahorro y Acciones de Cierre',
          description:
              'Supervisa el monto total neto y ahorros aplicados; luego abre Acciones para guardar en Mesa de Trabajo, generar PDF/WhatsApp o pasar a Caja.',
          tip: 'En la barra superior puedes ver cuántos ítems están listos o reiniciar el análisis si hiciste cambios.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
