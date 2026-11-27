import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'whatsapp_preview/whatsapp_preview_message_builder_part.dart';
part 'whatsapp_preview/whatsapp_preview_sections_part.dart';

class WhatsAppPreviewModal extends StatefulWidget {
  final String? initialClientName;
  final String? initialClientPhone;
  final bool isDark;
  final Map<String, dynamic>? cuota;
  final List<dynamic>? multipleCuotas;
  final double? totalDebt;
  final String? operationTitle;

  const WhatsAppPreviewModal({
    super.key,
    this.initialClientName,
    this.initialClientPhone,
    required this.isDark,
    this.cuota,
    this.multipleCuotas,
    this.totalDebt,
    this.operationTitle,
  });

  /// Abre el estudio de WhatsApp para una cuota individual
  static Future<void> showCuotaReminder({
    required BuildContext context,
    required Map<String, dynamic> cuota,
    String? clientName,
    String? clientPhone,
    required bool isDark,
    String? operationTitle,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => WhatsAppPreviewModal(
        cuota: cuota,
        initialClientName: clientName,
        initialClientPhone: clientPhone,
        isDark: isDark,
        operationTitle: operationTitle,
      ),
    );
  }

  /// Abre el estudio de WhatsApp para múltiples cuotas vencidas (desde perfil del cliente)
  static Future<void> showOverdueSummary({
    required BuildContext context,
    required List<dynamic> overdueCuotas,
    required double totalDebt,
    String? clientName,
    String? clientPhone,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => WhatsAppPreviewModal(
        multipleCuotas: overdueCuotas,
        totalDebt: totalDebt,
        initialClientName: clientName,
        initialClientPhone: clientPhone,
        isDark: isDark,
      ),
    );
  }

  @override
  State<WhatsAppPreviewModal> createState() => _WhatsAppPreviewModalState();
}

class _WhatsAppPreviewModalState extends State<WhatsAppPreviewModal> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _messageCtrl;

  String _activeTemplate = 'formal';
  bool _showDesglose = true;
  bool _showMora = true;
  bool _showCuentas = false;

  @override
  void initState() {
    super.initState();
    String phone = widget.initialClientPhone?.trim() ?? "";
    if (phone == "000000000" ||
        phone == "00000000" ||
        phone.replaceAll('0', '').isEmpty) {
      phone = "";
    }
    _phoneCtrl = TextEditingController(text: phone);
    _nameCtrl = TextEditingController(
      text: widget.initialClientName?.trim() ?? "Estimado cliente",
    );
    _messageCtrl = TextEditingController(
      text: _generateMessage(templateType: 'formal'),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback fn) => setState(fn);

  void _applyTemplate(String type) {
    setState(() {
      _activeTemplate = type;
      _messageCtrl.text = _generateMessage();
    });
  }

  double _calculateExigibleTotal() {
    if (widget.cuota != null) {
      final c = widget.cuota!;
      final double totalCuota = (num.tryParse(c['monto'].toString()) ?? 0.0)
          .toDouble();
      final double pagado =
          (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0)
              .toDouble();
      return totalCuota - pagado > 0 ? totalCuota - pagado : 0.0;
    }

    if (widget.multipleCuotas != null && widget.multipleCuotas!.isNotEmpty) {
      double sum = 0.0;
      for (final raw in widget.multipleCuotas!) {
        final c = raw is Map ? raw : (raw as dynamic);
        final monto =
            (num.tryParse((c['monto'] ?? c['amount'] ?? 0.0).toString()) ?? 0.0)
                .toDouble();
        final pagado =
            (num.tryParse(
                      (c['monto_pagado'] ?? c['montoPagado'] ?? 0.0).toString(),
                    ) ??
                    0.0)
                .toDouble();
        final falta = monto - pagado > 0 ? monto - pagado : 0.0;
        sum += falta;
      }
      if (sum > 0.01) return sum;
    }

    return widget.totalDebt ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: InteractiveSheetWrapper(
        title: "Estudio de WhatsApp",
        icon: Icons.chat_rounded,
        iconColor: const Color(0xFF25D366),
        backgroundColor: surfaceColor,
        applyEffectiveBottomPadding: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Revisa o edita libremente el mensaje antes de enviarlo por WhatsApp.",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 10),
                _buildContactHeaderBar(
                  context: context,
                  isDark: isDark,
                  cardBg: cardBg,
                  textColor: textColor,
                ),
                const SizedBox(height: 10),
                _buildTemplatesCarousel(isDark),
                const SizedBox(height: 8),
                _buildModuleChipsCarousel(isDark),
                const SizedBox(height: 10),
                _buildMessageHeaderRow(context, isDark),
                const SizedBox(height: 4),
                _buildMessageEditor(context, isDark, cardBg, textColor),
                const SizedBox(height: 14),
                _buildFooterActionsRow(context, isDark),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
