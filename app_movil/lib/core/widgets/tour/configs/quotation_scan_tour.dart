import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves globales de anclaje para la Guía Turística Interactiva de Escanear Lista (Cotización)
class QuotationScanTourKeys {
  final GlobalKey scenariosKey;
  final GlobalKey captureActionsKey;
  final GlobalKey clientHintKey;

  QuotationScanTourKeys({
    GlobalKey? scenariosKey,
    GlobalKey? captureActionsKey,
    GlobalKey? clientHintKey,
  })  : scenariosKey = scenariosKey ?? GlobalKey(),
        captureActionsKey = captureActionsKey ?? GlobalKey(),
        clientHintKey = clientHintKey ?? GlobalKey();
}

/// Configuración de la Guía Turística Interactiva para Escanear Lista de Cotización con IA
class QuotationScanTour {
  static const String screenId = 'quotation_scan_screen';

  static ScreenTourConfig buildConfig({
    required QuotationScanTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: screenId,
      screenTitle: 'Escanear Lista de Pedido',
      welcomeSummary:
          'Digitaliza listas de compras, pedidos al por mayor o requerimientos escolares a partir de fotos o documentos con Inteligencia Artificial.',
      icon: Icons.document_scanner_rounded,
      steps: [
        TourStep(
          id: 'step_scenarios',
          targetKey: keys.scenariosKey,
          title: 'Modalidades de Lista Adaptables',
          description:
              'El motor de IA reconoce automáticamente listas de compras para reponer, pedidos al por mayor o listas de útiles escolares.',
          tip:
              'No necesitas ordenar la lista previamente; la IA extrae ítems y cantidades automáticamente.',
          icon: Icons.tune_rounded,
        ),
        TourStep(
          id: 'step_capture_actions',
          targetKey: keys.captureActionsKey,
          title: 'Captura con Cámara o Galería',
          description:
              'Fotografía la lista en papel o selecciona una foto o captura de WhatsApp recibida de tu cliente.',
          tip:
              'Asegúrate de que la letra sea legible y el texto esté bien encuadrado.',
          icon: Icons.camera_alt_rounded,
        ),
        TourStep(
          id: 'step_client_hint',
          targetKey: keys.clientHintKey,
          title: 'Asignación Rápida a Cliente',
          description:
              'Tras extraer los artículos, podrás vincular la cotización generada a cualquier cliente o crear uno nuevo para enviarle su cotización por WhatsApp.',
          tip:
              'El cotizador inteligente calculará el stock disponible y el total automáticamente.',
          icon: Icons.person_search_outlined,
        ),
      ],
    );
  }
}
