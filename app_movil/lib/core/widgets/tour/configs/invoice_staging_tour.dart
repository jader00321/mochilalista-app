import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [InvoiceStagingScreen]
class InvoiceStagingTourKeys {
  final GlobalKey vendorCardKey;
  final GlobalKey smartGroupingBarKey;
  final GlobalKey productGroupsKey;
  final GlobalKey commitButtonKey;

  InvoiceStagingTourKeys({
    GlobalKey? vendorCardKey,
    GlobalKey? smartGroupingBarKey,
    GlobalKey? productGroupsKey,
    GlobalKey? commitButtonKey,
  }) : vendorCardKey =
           vendorCardKey ?? GlobalKey(debugLabel: 'inv_stg_tour_vendor'),
       smartGroupingBarKey =
           smartGroupingBarKey ?? GlobalKey(debugLabel: 'inv_stg_tour_grouping'),
       productGroupsKey =
           productGroupsKey ?? GlobalKey(debugLabel: 'inv_stg_tour_products'),
       commitButtonKey =
           commitButtonKey ?? GlobalKey(debugLabel: 'inv_stg_tour_commit');
}

/// Guía Turística Interactiva completa para [InvoiceStagingScreen] (4 pasos)
class InvoiceStagingTour {
  static final InvoiceStagingTourKeys defaultKeys = InvoiceStagingTourKeys();

  static ScreenTourConfig buildConfig({InvoiceStagingTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'invoice_staging_screen',
      screenTitle: 'Clasificar y Confirmar Stock',
      welcomeSummary:
          'Enlaza la factura con tu proveedor, agrupa variantes nuevas o existentes, define precios y ejecuta el ingreso atómico al inventario.',
      icon: Icons.inventory_rounded,
      steps: [
        TourStep(
          id: 'step_stg_vendor_card',
          targetKey: k.vendorCardKey,
          title: 'Tarjeta de Proveedor y Factura',
          description:
              'Verifica si la IA asoció la compra a un proveedor existente en tu directorio o creará uno nuevo, y revisa el monto total declarado del comprobante.',
          tip: 'Despliega esta tarjeta si necesitas buscar manualmente o cambiar al proveedor vinculado.',
          icon: Icons.local_shipping_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_stg_smart_grouping',
          targetKey: k.smartGroupingBarKey,
          title: 'Agrupación Inteligente: Nuevos vs Existentes',
          description:
              'Monitorea al instante cuántas variantes se vincularán a productos existentes de tu catálogo y cuántas se registrarán como artículos nuevos.',
          tip: 'La barra de progreso superior se actualiza automáticamente según vayas enlazando grupos.',
          icon: Icons.analytics_outlined,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_stg_edit_variants',
          targetKey: k.productGroupsKey,
          title: 'Edición de Presentaciones, Precios y Stock',
          description:
              'Cada bloque agrupa las variantes de un producto padre para definir su nombre, presentación de venta, precio final y stock entrante sin reescribir manualmente todo.',
          tip: 'Usa la lupa en cada grupo para re-vincularlo con otro producto de tu inventario si hace falta.',
          icon: Icons.tune_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_stg_atomic_commit',
          targetKey: k.commitButtonKey,
          title: 'Ingreso Atómico al Inventario',
          description:
              'Confirma la operación para guardar la factura en el historial y sumar todo el stock y costos en una sola transacción segura.',
          tip: 'Si existe algún conflicto o dato incompleto, el botón te llevará directo al ítem por corregir.',
          icon: Icons.save_alt_rounded,
          borderRadius: 14.0,
        ),
      ],
    );
  }
}
