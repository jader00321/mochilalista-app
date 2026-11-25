import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la pantalla de Cotización Manual
class ManualQuotationTourKeys {
  final GlobalKey identificationKey;
  final GlobalKey clientSchoolKey;
  final GlobalKey addProductsKey;
  final GlobalKey privacyEyeKey;
  final GlobalKey saveButtonKey;
  final GlobalKey footerKey;

  ManualQuotationTourKeys({
    GlobalKey? identificationKey,
    GlobalKey? clientSchoolKey,
    GlobalKey? addProductsKey,
    GlobalKey? privacyEyeKey,
    GlobalKey? saveButtonKey,
    GlobalKey? footerKey,
  }) : identificationKey =
           identificationKey ?? GlobalKey(debugLabel: 'mq_tour_identification'),
       clientSchoolKey =
           clientSchoolKey ?? GlobalKey(debugLabel: 'mq_tour_client_school'),
       addProductsKey =
           addProductsKey ?? GlobalKey(debugLabel: 'mq_tour_add_products'),
       privacyEyeKey =
           privacyEyeKey ?? GlobalKey(debugLabel: 'mq_tour_privacy_eye'),
       saveButtonKey =
           saveButtonKey ?? GlobalKey(debugLabel: 'mq_tour_save_btn'),
       footerKey = footerKey ?? GlobalKey(debugLabel: 'mq_tour_footer');
}

/// Guía Turística Interactiva completa para ManualQuotationScreen (6 pasos)
class ManualQuotationTour {
  static final ManualQuotationTourKeys defaultKeys = ManualQuotationTourKeys();

  static ScreenTourConfig buildConfig({
    ManualQuotationTourKeys? keys,
    Future<void> Function()? onExpandIdentification,
    Future<void> Function()? onRestoreIdentification,
    Future<void> Function()? onExpandClientSchool,
    Future<void> Function()? onRestoreClientSchool,
    Future<void> Function()? onExpandFooter,
    Future<void> Function()? onRestoreFooter,
  }) {
    final k = keys ?? defaultKeys;

    Future<void> restoreAll() async {
      await onRestoreIdentification?.call();
      await onRestoreClientSchool?.call();
      await onRestoreFooter?.call();
    }

    return ScreenTourConfig(
      screenId: 'manual_quotation_screen',
      screenTitle: 'Cotización Manual',
      welcomeSummary:
          'Arma proformas y pedidos detallados paso a paso, vincula cliente o colegio, protege tus márgenes en mostrador y convierte a venta al instante.',
      icon: Icons.edit_note_rounded,
      onCancel: restoreAll,
      onDismiss: restoreAll,
      steps: [
        TourStep(
          id: 'step_mq_identification',
          targetKey: k.identificationKey,
          title: 'Identificación de Cotización',
          description:
              'Personaliza el título de la cotización o conserva el nombre inteligente autogenerado y añade notas internas para el pedido.',
          tip: 'Si editaste el título a mano, puedes volver al nombre automático con el botón de restauración.',
          icon: Icons.description_outlined,
          borderRadius: 16.0,
          onBeforeStep: onExpandIdentification,
          onAfterStep: onRestoreIdentification,
        ),
        TourStep(
          id: 'step_mq_client_school',
          targetKey: k.clientSchoolKey,
          title: 'Cliente y Colegio',
          description:
              'Busca un cliente existente en tu directorio CRM, elige si deseas guardarlo en Mis Clientes e indica colegio o grado escolar.',
          tip: 'Vincular al cliente facilita enviar su cotización por WhatsApp o cobrar luego al crédito.',
          icon: Icons.school_outlined,
          borderRadius: 16.0,
          onBeforeStep: onExpandClientSchool,
          onAfterStep: onRestoreClientSchool,
        ),
        TourStep(
          id: 'step_mq_add_products',
          targetKey: k.addProductsKey,
          title: 'Agregar Productos del Catálogo',
          description:
              'Pulsa Buscar Productos para consultar stock en vivo, elegir presentaciones o añadir artículos de libre escritura y reordenarlos.',
          tip: 'Cuando agregues productos podrás arrastrar cada tarjeta para ordenar la proforma.',
          icon: Icons.add_shopping_cart_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_mq_privacy_eye',
          targetKey: k.privacyEyeKey,
          title: 'Modo Vendedor y Privacidad',
          description:
              'Oculta o muestra al instante tus costos y ganancias estimadas cuando estés revisando la cotización junto al cliente.',
          tip: 'Muy útil en mostrador para mostrar solo precios finales sin revelar tu margen.',
          icon: Icons.visibility_outlined,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'step_mq_save_btn',
          targetKey: k.saveButtonKey,
          title: 'Guardar Proforma o Borrador',
          description:
              'Guarda tu cotización en la Mesa de Trabajo sin descontar stock físico hasta que decidas cerrar la venta o enviarla por PDF/WhatsApp.',
          icon: Icons.save_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'step_mq_footer',
          targetKey: k.footerKey,
          title: 'Resumen Total y Venta Directa',
          description:
              'Desliza o toca la barra inferior para ver ahorro aplicado, ganancia estimada y convertir la cotización en venta real con un toque.',
          tip: 'También funciona como acceso directo a Caja cuando el cliente confirma su compra.',
          icon: Icons.point_of_sale_rounded,
          borderRadius: 16.0,
          onBeforeStep: onExpandFooter,
          onAfterStep: onRestoreFooter,
        ),
      ],
    );
  }
}
