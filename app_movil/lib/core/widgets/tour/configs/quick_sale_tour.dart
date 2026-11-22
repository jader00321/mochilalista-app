import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Venta Rápida / Caja
class QuickSaleTourKeys {
  final GlobalKey headerClientKey;
  final GlobalKey searchScannerKey;
  final GlobalKey cartContainerKey;
  final GlobalKey checkoutBottomKey;

  QuickSaleTourKeys({
    GlobalKey? headerClientKey,
    GlobalKey? searchScannerKey,
    GlobalKey? cartContainerKey,
    GlobalKey? checkoutBottomKey,
  })  : headerClientKey = headerClientKey ?? GlobalKey(debugLabel: 'qs_tour_header_client'),
        searchScannerKey = searchScannerKey ?? GlobalKey(debugLabel: 'qs_tour_search_scanner'),
        cartContainerKey = cartContainerKey ?? GlobalKey(debugLabel: 'qs_tour_cart_container'),
        checkoutBottomKey = checkoutBottomKey ?? GlobalKey(debugLabel: 'qs_tour_checkout_bottom');
}

/// Configuración de la Guía Turística para QuickSaleScreen
class QuickSaleTour {
  static final QuickSaleTourKeys defaultKeys = QuickSaleTourKeys();

  static ScreenTourConfig buildConfig({QuickSaleTourKeys? keys}) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'quick_sale_screen',
      screenTitle: 'Caja Rápida',
      welcomeSummary:
          'Tu punto de venta ágil para despachar a tus clientes en segundos, controlar existencias y emitir notas de venta.',
      icon: Icons.point_of_sale_rounded,
      steps: [
        TourStep(
          id: 'step_header_client',
          targetKey: k.headerClientKey,
          title: 'Cliente o Venta al Paso',
          description:
              'Selecciona un cliente recurrente para acumular su historial o deja la venta en modo "Cliente al Paso" para compras rápidas de mostrador.',
          tip: 'Puedes registrar un nuevo cliente al instante sin salir de la caja.',
          icon: Icons.person_search_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_search_scanner',
          targetKey: k.searchScannerKey,
          title: 'Buscador y Escáner Rápido',
          description:
              'Encuentra artículos por nombre o toca el ícono de cámara para escanear etiquetas de código de barras al instante.',
          tip: 'Si tienes lectores USB o Bluetooth físicos, también funcionan automáticamente sin tocar la pantalla.',
          icon: Icons.qr_code_scanner_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_cart_items',
          targetKey: k.cartContainerKey,
          title: 'Carrito Dinámico y Ajustes',
          description:
              'Toca cualquier producto de la lista para editar la cantidad, ajustar el precio de venta o cambiar de presentación con un solo toque.',
          tip: 'Usa el botón del ojo en la barra superior para ocultar los márgenes de ganancia cuando tu cliente esté mirando.',
          icon: Icons.shopping_cart_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_checkout_action',
          targetKey: k.checkoutBottomKey,
          title: 'Cobro y Métodos de Pago',
          description:
              'Presiona Cobrar para registrar el pago mediante Efectivo, Yape/Plin, Transferencia o Fiado/Crédito. El stock se descuenta automáticamente y puedes imprimir el ticket o enviarlo por WhatsApp.',
          tip: 'Si el cliente paga con efectivo, el sistema te calcula el vuelto exacto.',
          icon: Icons.payments_rounded,
          borderRadius: 18.0,
        ),
      ],
    );
  }
}
