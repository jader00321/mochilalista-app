import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [ProductEditScreen]
class ProductEditTourKeys {
  final generalInfoKey = GlobalKey(
    debugLabel: 'prod_edit_tour_general_info',
  );
  final stockStrategyKey = GlobalKey(
    debugLabel: 'prod_edit_tour_stock_strategy',
  );
  final baseCostKey = GlobalKey(
    debugLabel: 'prod_edit_tour_base_cost',
  );
  final presentationsKey = GlobalKey(
    debugLabel: 'prod_edit_tour_presentations',
  );
  final saveBarKey = GlobalKey(
    debugLabel: 'prod_edit_tour_save_bar',
  );
}

/// Configuración de la Guía Turística Interactiva para [ProductEditScreen]
class ProductEditTour {
  static final ProductEditTourKeys defaultKeys = ProductEditTourKeys();

  static ScreenTourConfig buildConfig({
    ProductEditTourKeys? keys,
    Future<void> Function()? onExpandPresentationsForTour,
    Future<void> Function()? onRestorePresentationsAfterTour,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'product_edit_screen',
      screenTitle: 'Edición de Producto',
      welcomeSummary:
          'Actualiza datos generales, configura stock compartido o independiente, recalcula costos base, organiza presentaciones con Undo y guarda con validación.',
      icon: Icons.edit_note_rounded,
      onCancel: onRestorePresentationsAfterTour,
      onDismiss: onRestorePresentationsAfterTour,
      steps: [
        TourStep(
          id: 'step_pe_general_info',
          targetKey: k.generalInfoKey,
          title: 'Datos Generales y Código de Barras',
          description:
              'Edita el nombre comercial, visibilidad (Público/Privado), marca, categoría, proveedor principal, descripción, imagen y escaneo o edición de código de barras.',
          tip:
              'Un buen nombre y código de barras aceleran las coincidencias en Caja Rápida e Ingesta con IA.',
          icon: Icons.qr_code_scanner_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_pe_stock_strategy',
          targetKey: k.stockStrategyKey,
          title: 'Estrategia de Stock (Compartido vs. Propio)',
          description:
              'Elige si todas las presentaciones descuentan de una misma bolsa común por factor de conversión (Compartido), si cada variante maneja su stock propio (Independiente) o Mixto.',
          tip:
              'En modo Compartido o Mixto evita doble conteo al registrar ingresos de almacén desde un único campo base.',
          icon: Icons.hub_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_pe_base_cost',
          targetKey: k.baseCostKey,
          title: 'Costo Base y Asesor de Variantes',
          description:
              'Define el Costo Base Unitario en stock compartido (o el costo por presentación independiente) para recalcular automáticamente costos sugeridos, márgenes y avisos de unidad.',
          tip:
              'El asesor detecta cuándo conviene agregar una presentación unitaria para aprovechar unidades sueltas.',
          icon: Icons.calculate_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_pe_presentations',
          targetKey: k.presentationsKey,
          title: 'Presentaciones, Extracción y Deshacer (Undo)',
          description:
              'Edita precios, redondeos rápidos, reordena o extrae/corta una variante hacia un producto nuevo. Cuando realizas cambios, arriba aparecen Deshacer y Restaurar.',
          tip:
              'Puedes colapsar variantes y usar la barra de salto rápido si el producto tiene múltiples empaques.',
          icon: Icons.layers_rounded,
          borderRadius: 16.0,
          onBeforeStep: onExpandPresentationsForTour,
          onAfterStep: onRestorePresentationsAfterTour,
        ),
        TourStep(
          id: 'step_pe_save_bar',
          targetKey: k.saveBarKey,
          title: 'Barra de Guardado y Protección de Cambios',
          description:
              'Pulsa GUARDAR CAMBIOS (o el check superior) para validar precios, factores y stock; si intentas salir con ediciones pendientes, el diálogo protege tu trabajo.',
          tip:
              'Nada se sobrescribe en base de datos hasta confirmar el guardado validado.',
          icon: Icons.save_rounded,
          borderRadius: 16.0,
          onBeforeStep: onRestorePresentationsAfterTour,
        ),
      ],
    );
  }
}
