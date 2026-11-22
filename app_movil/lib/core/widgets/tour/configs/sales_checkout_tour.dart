import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves globales de anclaje para la Guía Turística Interactiva de Cobro de Venta (Checkout)
class SalesCheckoutTourKeys {
  final GlobalKey clientSelectorKey;
  final GlobalKey paymentMethodsKey;
  final GlobalKey discountsLoyaltyKey;
  final GlobalKey confirmSaleButtonKey;

  SalesCheckoutTourKeys({
    GlobalKey? clientSelectorKey,
    GlobalKey? paymentMethodsKey,
    GlobalKey? discountsLoyaltyKey,
    GlobalKey? confirmSaleButtonKey,
  })  : clientSelectorKey = clientSelectorKey ?? GlobalKey(),
        paymentMethodsKey = paymentMethodsKey ?? GlobalKey(),
        discountsLoyaltyKey = discountsLoyaltyKey ?? GlobalKey(),
        confirmSaleButtonKey = confirmSaleButtonKey ?? GlobalKey();
}

/// Configuración de la Guía Turística Interactiva para Cobro de Venta (Checkout)
class SalesCheckoutTour {
  static const String screenId = 'sales_checkout_screen';

  static ScreenTourConfig buildConfig({
    required SalesCheckoutTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: screenId,
      screenTitle: 'Cobro de Venta (Checkout)',
      welcomeSummary:
          'Configura las condiciones de cobro, asigna el cliente, aplica descuentos y genera el comprobante de venta de forma rápida y segura.',
      icon: Icons.point_of_sale_rounded,
      steps: [
        TourStep(
          id: 'step_client_selector',
          targetKey: keys.clientSelectorKey,
          title: 'Selección de Cliente',
          description:
              'Asigna la venta a un cliente registrado o al público general para acumular puntos de fidelización y controlar su cuenta corriente.',
          tip:
              'Las ventas a crédito requieren obligatoriamente un cliente con teléfono o documento registrado.',
          icon: Icons.person_pin_circle_outlined,
        ),
        TourStep(
          id: 'step_payment_methods',
          targetKey: keys.paymentMethodsKey,
          title: 'Modalidad y Método de Pago',
          description:
              'Registra cobros al contado en efectivo o billeteras digitales (Yape/Plin), o configura un crédito en cuotas con intereses transparentes.',
          tip:
              'Si seleccionas venta al crédito, el sistema genera el cronograma de pagos automáticamente.',
          icon: Icons.credit_card_outlined,
        ),
        TourStep(
          id: 'step_discounts_loyalty',
          targetKey: keys.discountsLoyaltyKey,
          title: 'Descuentos y Premios por Puntos',
          description:
              'Aplica rebajas directas sobre el total o canjea premios que el cliente haya acumulado con sus compras anteriores.',
          tip:
              'Los descuentos se reflejan al instante en el total a pagar y en el ticket impreso.',
          icon: Icons.card_giftcard_outlined,
        ),
        TourStep(
          id: 'step_confirm_sale',
          targetKey: keys.confirmSaleButtonKey,
          title: 'Cierre y Emisión de Venta',
          description:
              'Confirma la venta para descargar las existencias del inventario, registrar el ingreso en caja y generar el comprobante listo para imprimir o compartir.',
          tip:
              'El comprobante se puede imprimir por Bluetooth o enviar directamente por WhatsApp.',
          icon: Icons.check_circle_outline,
        ),
      ],
    );
  }
}
