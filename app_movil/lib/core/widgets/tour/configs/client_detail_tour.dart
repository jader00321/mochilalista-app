import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [ClientDetailScreen]
class ClientDetailTourKeys {
  final balanceCardKey = GlobalKey();
  final registerPaymentKey = GlobalKey();
  final movementsTabsKey = GlobalKey();
  final whatsappContactKey = GlobalKey();
}

/// Configuración pedagógica de la Guía Turística para [ClientDetailScreen]
class ClientDetailTour {
  static ScreenTourConfig buildConfig({
    required ClientDetailTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: 'client_detail_screen',
      screenTitle: 'Detalle de Cliente y Abonos',
      welcomeSummary:
          'Supervisa el estado financiero de tu cliente, registra abonos a sus deudas y mantén un registro contable transparente de cada compra y cotización.',
      icon: Icons.person_pin_rounded,
      steps: [
        TourStep(
          id: 'client_balance_card',
          targetKey: keys.balanceCardKey,
          title: 'Balance Financiero y Reputación',
          description:
              'Visualiza la deuda pendiente total, el límite de crédito disponible y el nivel de confianza comercial otorgado al cliente según su puntualidad.',
          tip:
              'El semáforo de confianza te ayuda a decidir si autorizar nuevos créditos en mostrador.',
          icon: Icons.account_balance_wallet_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'client_register_payment',
          targetKey: keys.registerPaymentKey,
          title: 'Registrar Abonos y Amortizaciones',
          description:
              'Abona cobros parciales o cancelaciones totales. El sistema amortiza en cascada desde la cuota más antigua y actualiza el saldo contable al instante.',
          tip:
              'Cada abono registrado queda respaldado cronológicamente en el libro contable del cliente.',
          icon: Icons.payments_rounded,
          borderRadius: 24.0,
        ),
        TourStep(
          id: 'client_movements_tabs',
          targetKey: keys.movementsTabsKey,
          title: 'Historial y Movimientos Contables',
          description:
              'Navega con facilidad entre el extracto de cuenta cronológico, las compras y comprobantes de venta emitidos, y las cotizaciones escolares guardadas.',
          tip:
              'Toca cualquier registro para ver su desglose detallado o compartir un duplicado.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'client_whatsapp_contact',
          targetKey: keys.whatsappContactKey,
          title: 'Cobranza y Recordatorio por WhatsApp',
          description:
              'Genera en un solo toque un recordatorio amigable por WhatsApp con el desglose exacto de cuotas vencidas y tus métodos de pago oficiales.',
          tip:
              'Mantén una comunicación cercana y profesional con tu cliente sin fricciones de cobranza.',
          icon: Icons.chat_rounded,
          borderRadius: 14.0,
        ),
      ],
    );
  }
}
