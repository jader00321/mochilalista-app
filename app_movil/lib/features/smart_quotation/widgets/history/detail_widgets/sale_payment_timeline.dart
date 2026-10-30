import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_reminder_modal.dart';

class SalePaymentTimeline extends StatelessWidget {
  final List<dynamic> cuotasRaw;
  final bool isDark;
  final String? clientPhone;
  final String? clientName;
  final int? clientId;
  final int? saleId;
  final VoidCallback? onPaymentSuccess;

  const SalePaymentTimeline({
    super.key,
    required this.cuotasRaw,
    required this.isDark,
    this.clientPhone,
    this.clientName,
    this.clientId,
    this.saleId,
    this.onPaymentSuccess,
  });

  void _openCuotaPayment(BuildContext context, Map<String, dynamic> c) async {
    if (clientId == null || clientId! <= 0) return;
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final client = await saleProv.getClientById(clientId!);
    if (client != null && context.mounted) {
      final double cuotaMonto = (c['monto'] as num).toDouble();
      final double cuotaPagado = (c['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      final double saldoCuota = cuotaMonto - cuotaPagado;

      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PaymentEntryModal(
          client: client,
          initialTargetType: 'cuota',
          initialTargetId: c['id'] as int?,
          initialAmount: saldoCuota > 0.01 ? saldoCuota : cuotaMonto,
          onPaymentSuccess: () {
            onPaymentSuccess?.call();
            saleProv.silentRefresh();
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cuotasRaw.isEmpty) return const SizedBox.shrink();

    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: isDark ? Colors.orange[300] : Colors.orange[900],
          collapsedIconColor: isDark ? Colors.orange[300] : Colors.orange[900],
          title: Row(
            children: [
              Icon(Icons.calendar_month, size: 22, color: isDark ? Colors.orange[300] : Colors.orange[900]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Plan de Cuotas (${cuotasRaw.length})",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[900]),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: cuotasRaw.map((cRaw) {
                  final c = Map<String, dynamic>.from(cRaw as Map);
                  final bool cuotaPagada = c['estado'] == 'pagado';

                  DateTime? dueDate;
                  try {
                    dueDate = DateTime.parse(c['fecha_vencimiento'].toString());
                  } catch (_) {}

                  final bool isVencido = !cuotaPagada &&
                      dueDate != null &&
                      dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                  final String dateFormatted = dueDate != null
                      ? DateFormat('dd/MM/yyyy').format(dueDate)
                      : c['fecha_vencimiento'].toString();

                  final Color badgeBg = cuotaPagada
                      ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50)
                      : (isVencido
                          ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.shade50)
                          : (isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50));

                  final Color badgeBorder = cuotaPagada
                      ? (isDark ? Colors.green.shade700 : Colors.green.shade200)
                      : (isVencido
                          ? (isDark ? Colors.red.shade700 : Colors.red.shade200)
                          : (isDark ? Colors.orange.shade700 : Colors.orange.shade200));

                  final Color badgeColor = cuotaPagada
                      ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                      : (isVencido
                          ? (isDark ? Colors.red.shade300 : Colors.red.shade800)
                          : (isDark ? Colors.orange.shade300 : Colors.orange.shade900));

                  final String badgeLabel = cuotaPagada
                      ? "PAGADO"
                      : (isVencido ? "VENCIDO" : "PENDIENTE");

                  final IconData badgeIcon = cuotaPagada
                      ? Icons.check_circle
                      : (isVencido ? Icons.error_outline : Icons.hourglass_top);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // NIVEL 1: Número de cuota, Fecha de vencimiento y Monto
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: cuotaPagada
                                  ? (isDark ? Colors.green.withValues(alpha: 0.25) : Colors.green.shade100)
                                  : (isDark ? Colors.orange.withValues(alpha: 0.25) : Colors.orange.shade100),
                              child: Text(
                                "${c['numero_cuota']}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cuotaPagada
                                      ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                                      : (isDark ? Colors.orange.shade300 : Colors.orange.shade900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Vence: $dateFormatted",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppCurrency.format(c['monto']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // NIVEL 2: Badge de Estado y Botones de Acción
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeBorder, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(badgeIcon, size: 12, color: badgeColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Acciones si está pendiente
                              if (!cuotaPagada)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        CuotaReminderModal.show(
                                          context: context,
                                          cuota: c,
                                          dateFormatted: dateFormatted,
                                          clientName: clientName,
                                          clientPhone: clientPhone,
                                          isDark: isDark,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chat, size: 14, color: Color(0xFF25D366)),
                                            SizedBox(width: 4),
                                            Text(
                                              "Recordar",
                                              style: TextStyle(
                                                color: Color(0xFF25D366),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    if (clientId != null && clientId! > 0)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _openCuotaPayment(context, c),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.payments_outlined,
                                                size: 14,
                                                color: isDark ? Colors.tealAccent[400] : Colors.teal.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Cobrar",
                                                style: TextStyle(
                                                  color: isDark ? Colors.tealAccent[400] : Colors.teal.shade800,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
