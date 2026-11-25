import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [SaleFinancialDetailScreen]
class SaleFinancialDetailTourKeys {
  final receiptButtonKey = GlobalKey(
    debugLabel: 'sale_fin_tour_receipt_btn',
  );
  final balanceCardKey = GlobalKey(
    debugLabel: 'sale_fin_tour_balance_card',
  );
  final scheduleTileKey = GlobalKey(
    debugLabel: 'sale_fin_tour_schedule_tile',
  );
  final installmentActionsKey = GlobalKey(
    debugLabel: 'sale_fin_tour_installment_actions',
  );
  final installmentDateKey = GlobalKey(
    debugLabel: 'sale_fin_tour_installment_date',
  );
  final exportActionsKey = GlobalKey(
    debugLabel: 'sale_fin_tour_export_actions',
  );
}

/// Configuración de la Guía Turística para [SaleFinancialDetailScreen]
class SaleFinancialDetailTour {
  static final SaleFinancialDetailTourKeys defaultKeys =
      SaleFinancialDetailTourKeys();

  static ScreenTourConfig buildConfig({
    SaleFinancialDetailTourKeys? keys,
    Future<void> Function()? onExpandFirstInstallment,
    Future<void> Function()? onRestoreFirstInstallment,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'sale_financial_detail_screen',
      screenTitle: 'Detalle Financiero de Venta',
      welcomeSummary:
          'Consulta el balance de cuotas e intereses, despliega cada vencimiento con Base y Mora, cobra parcial o totalmente y comparte estados de cuenta en PDF o WhatsApp.',
      icon: Icons.account_balance_wallet_rounded,
      onCancel: onRestoreFirstInstallment,
      onDismiss: onRestoreFirstInstallment,
      steps: [
        TourStep(
          id: 'step_sfd_receipt',
          targetKey: k.receiptButtonKey,
          title: 'Ver Comprobante y Resumen',
          description:
              'Abre el comprobante original de la operación con el número secuencial, ficha del cliente, artículos vendidos y estado logístico de entrega.',
          tip:
              'Desde el comprobante completo también puedes imprimir ticket térmico o emitir una copia para el comprador.',
          icon: Icons.receipt_long_rounded,
          borderRadius: 14.0,
        ),
        TourStep(
          id: 'step_sfd_balance',
          targetKey: k.balanceCardKey,
          title: 'Tarjeta de Balance Financiero',
          description:
              'Revisa de un vistazo el saldo pendiente exigible, el monto o costo total, lo abonado acumulado, el interés aplicado al plan y cualquier mora acumulada.',
          tip:
              'Cuando el saldo llega a S/ 0.00 el indicador cambia automáticamente a verde confirmando la cancelación.',
          icon: Icons.analytics_outlined,
          borderRadius: 20.0,
          onBeforeStep: onRestoreFirstInstallment,
        ),
        TourStep(
          id: 'step_sfd_schedule_tile',
          targetKey: k.scheduleTileKey,
          title: 'Cronograma de Cuotas (Base + Mora + Auto)',
          description:
              'Cada cuota muestra estado (Pendiente, Vence Hoy, Vencida o Pagada), etiqueta Auto si tiene mora automática y su tarjeta desplegable con Monto Base, Recargo por Mora, Abonado y Saldo.',
          tip:
              'Toca cualquier cuota del cronograma para expandir o contraer su desglose financiero y opciones de gestión.',
          icon: Icons.calendar_view_day_rounded,
          borderRadius: 16.0,
          onBeforeStep: onExpandFirstInstallment,
        ),
        TourStep(
          id: 'step_sfd_collection_actions',
          targetKey: k.installmentActionsKey,
          title: 'Acciones de Cobro, Mora y Recordar',
          description:
              'En cuotas vencidas puedes aplicar recargo desde "Mora" y en vigentes programar reglas preventivas con "Prog. Mora". Usa "Recordar" para cobrar por WhatsApp y "Cobrar" para registrar el pago de esa cuota.',
          tip:
              'Al pulsar "Cobrar" el monto pendiente de la cuota se pre-carga listo para confirmar en un toque.',
          icon: Icons.payments_rounded,
          borderRadius: 10.0,
          onBeforeStep: onExpandFirstInstallment,
        ),
        TourStep(
          id: 'step_sfd_date_adjust',
          targetKey: k.installmentDateKey,
          title: 'Edición de Fecha y Ajustes del Plan',
          description:
              'Pulsa "Fecha" para reprogramar el vencimiento de la cuota si acordaste una prórroga con el cliente; la morosidad y alertas se recalculan al instante sin alterar tus abonos previos.',
          tip:
              'Desliza hacia abajo en cualquier momento para recargar saldos y revisar los productos incluidos.',
          icon: Icons.edit_calendar_rounded,
          borderRadius: 10.0,
          onBeforeStep: onExpandFirstInstallment,
        ),
        TourStep(
          id: 'step_sfd_export_actions',
          targetKey: k.exportActionsKey,
          title: 'Exportación y Envío (PDF y WhatsApp)',
          description:
              'Desde los accesos superiores genera el estado de cuenta y cronograma en PDF profesional o envíalo directamente por WhatsApp al número registrado del cliente.',
          tip:
              'El resumen enviado incluye montos base, moras vigentes y detalle claro de pagos realizados.',
          icon: Icons.picture_as_pdf_rounded,
          borderRadius: 12.0,
          onBeforeStep: onRestoreFirstInstallment,
        ),
      ],
    );
  }
}
