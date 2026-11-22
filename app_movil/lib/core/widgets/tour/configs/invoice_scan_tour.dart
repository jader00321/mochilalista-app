import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves globales de anclaje para la Guía Turística Interactiva de Escanear Factura
class InvoiceScanTourKeys {
  final GlobalKey heroQuotaKey;
  final GlobalKey cameraCardKey;
  final GlobalKey galleryCardKey;
  final GlobalKey historyButtonKey;

  InvoiceScanTourKeys({
    GlobalKey? heroQuotaKey,
    GlobalKey? cameraCardKey,
    GlobalKey? galleryCardKey,
    GlobalKey? historyButtonKey,
  })  : heroQuotaKey = heroQuotaKey ?? GlobalKey(),
        cameraCardKey = cameraCardKey ?? GlobalKey(),
        galleryCardKey = galleryCardKey ?? GlobalKey(),
        historyButtonKey = historyButtonKey ?? GlobalKey();
}

/// Configuración de la Guía Turística Interactiva para Escanear Factura con IA
class InvoiceScanTour {
  static const String screenId = 'invoice_scan_screen';

  static ScreenTourConfig buildConfig({
    required InvoiceScanTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: screenId,
      screenTitle: 'Escanear Factura con IA',
      welcomeSummary:
          'Digitaliza facturas físicas y boletas de compra de tus proveedores con Inteligencia Artificial para actualizar tu stock y costos al instante.',
      icon: Icons.receipt_long_rounded,
      steps: [
        TourStep(
          id: 'step_hero_quota',
          targetKey: keys.heroQuotaKey,
          title: 'Saldo de Escaneos IA en Vivo',
          description:
              'Supervisa en tiempo real tus escaneos inteligentes disponibles antes de procesar una factura física o digital.',
          tip:
              'Cada factura procesada con éxito descuenta 1 escaneo de tu saldo oficial.',
          icon: Icons.auto_awesome_rounded,
        ),
        TourStep(
          id: 'step_camera_card',
          targetKey: keys.cameraCardKey,
          title: 'Captura con Cámara',
          description:
              'Toma una foto nítida directamente desde arriba sobre una superficie plana y bien iluminada para máxima precisión.',
          tip:
              'Evita sombras y reflejos directos sobre los números y descripciones de la factura.',
          icon: Icons.camera_alt_outlined,
        ),
        TourStep(
          id: 'step_gallery_card',
          targetKey: keys.galleryCardKey,
          title: 'Subida desde Galería / Archivos',
          description:
              'Importa imágenes capturadas previamente o documentos de facturas almacenados en tu dispositivo móvil.',
          tip:
              'Formatos soportados: JPG, PNG e imágenes de alta definición.',
          icon: Icons.photo_library_outlined,
        ),
        TourStep(
          id: 'step_history_button',
          targetKey: keys.historyButtonKey,
          title: 'Historial de Facturas Procesadas',
          description:
              'Revisa el registro cronológico de todas las compras digitalizadas, con montos, fechas y estado de reposición.',
          tip:
              'Puedes consultar detalles de facturas pasadas en cualquier momento desde este acceso directo.',
          icon: Icons.history_rounded,
        ),
      ],
    );
  }
}
