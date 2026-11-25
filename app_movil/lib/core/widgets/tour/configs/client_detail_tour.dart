import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [ClientDetailScreen]
class ClientDetailTourKeys {
  final balanceCardKey = GlobalKey(debugLabel: 'client_tour_balance_card');
  final registerPaymentKey = GlobalKey(
    debugLabel: 'client_tour_register_payment',
  );
  final loanActionsKey = GlobalKey(debugLabel: 'client_tour_loan_actions');
  final quickActionsKey = GlobalKey(debugLabel: 'client_tour_quick_actions');
  final whatsappContactKey = GlobalKey(
    debugLabel: 'client_tour_whatsapp_contact',
  );
  final movementsTabsKey = GlobalKey(debugLabel: 'client_tour_movements_tabs');
  final optionsMenuKey = GlobalKey(debugLabel: 'client_tour_options_menu');
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
          'Supervisa la reputación crediticia, otorga préstamos o retiros de saldo, registra abonos en cascada y gestiona cobros por WhatsApp.',
      icon: Icons.person_pin_rounded,
      steps: [
        TourStep(
          id: 'client_balance_card',
          targetKey: keys.balanceCardKey,
          title: 'Balance, Semáforo de Crédito y Reputación',
          description:
              'Visualiza la deuda activa, saldo a favor, nivel de puntualidad, racha de pagos y puntos acumulados, junto con el semáforo de reputación y límite sugerido.',
          tip:
              'Toca la insignia de reputación y puntos para revisar recompensas o decidir si autorizar nuevos créditos en mostrador.',
          icon: Icons.account_balance_wallet_rounded,
          borderRadius: 18.0,
        ),
        TourStep(
          id: 'client_register_payment',
          targetKey: keys.registerPaymentKey,
          title: 'Abonar a Deuda y Amortizaciones',
          description:
              'Registra pagos parciales o cancelaciones totales. El sistema distribuye el monto automáticamente desde las ventas y cuotas pendientes más antiguas.',
          tip:
              'Cada abono queda asentado cronológicamente en el libro contable y actualiza al instante el saldo del cliente.',
          icon: Icons.payments_rounded,
          borderRadius: 24.0,
        ),
        TourStep(
          id: 'client_loan_operations',
          targetKey: keys.loanActionsKey,
          title: 'Modal Operaciones Financieras (+ Préstamo)',
          description:
              'Toca "+ Préstamo" para abrir el modal dual de Operaciones Financieras: otorga un préstamo en cuotas con cronograma o pago único, o usa Retirar Saldo a favor disponible.',
          tip:
              'Dentro del modal encontrarás una tarjeta retraíble con el límite de crédito sugerido según el historial de puntualidad.',
          icon: Icons.account_balance_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'client_quick_actions',
          targetKey: keys.quickActionsKey,
          title: 'Accesos Rápidos Comerciales',
          description:
              'Lleva al cliente directo a Caja Rápida o inicia una Nueva Cotización (Cotizar) con su ficha pre-cargada; también puedes pulsar Ver Analítica arriba para ver su volumen de compra.',
          tip:
              'Atiende ventas nuevas y cotizaciones escolares desde la ficha sin volver a buscar al cliente.',
          icon: Icons.bolt_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'client_whatsapp_contact',
          targetKey: keys.whatsappContactKey,
          title: 'Recordatorio por WhatsApp (Recordar)',
          description:
              'Pulsa el botón Recordar o el contacto de WhatsApp para enviar un estado de cuenta amable con el desglose exacto de cuotas vencidas y tus medios de pago oficiales listos para compartir.',
          tip:
              'También verás acceso directo para recordar cobranzas cuando existan cuotas atrasadas.',
          icon: Icons.chat_rounded,
          borderRadius: 12.0,
        ),
        TourStep(
          id: 'client_movements_tabs',
          targetKey: keys.movementsTabsKey,
          title: 'Pestañas Contables del Cliente',
          description:
              'Alterna entre Estado de Cuenta (movimientos contables de ventas, préstamos y abonos), Compras (comprobantes emitidos y cronogramas de cuotas) y Listas / Cotiz. (proformas guardadas).',
          tip:
              'Toca cualquier venta o movimiento en las pestañas para abrir su detalle financiero o emitir un duplicado.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'client_options_menu',
          targetKey: keys.optionsMenuKey,
          title: 'Menú Superior de Gestión',
          description:
              'Desde el menú de tres puntos superior puedes editar teléfono, DNI, dirección o notas del cliente, y ejecutar opciones administrativas o eliminación protegida.',
          tip:
              'La eliminación valida deudas activas para evitar borrar historiales contables críticos por accidente.',
          icon: Icons.more_vert_rounded,
          borderRadius: 12.0,
        ),
      ],
    );
  }
}
