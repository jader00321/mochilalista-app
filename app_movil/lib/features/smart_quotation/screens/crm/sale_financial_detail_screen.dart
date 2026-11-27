import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_financial_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';

part 'sale_financial_detail/sale_financial_balance_card.dart';
part 'sale_financial_detail/sale_financial_logistics_dialogs_mixin.dart';
part 'sale_financial_detail/sale_financial_installment_actions_mixin.dart';
part 'sale_financial_detail/sale_financial_installments_mixin.dart';
part 'sale_financial_detail/sale_financial_items_section.dart';

class SaleFinancialDetailScreen extends StatefulWidget {
  final int saleId;
  final bool autoTriggerTour;
  final SaleFinancialDetailTourKeys? tourKeys;

  const SaleFinancialDetailScreen({
    super.key,
    required this.saleId,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<SaleFinancialDetailScreen> createState() =>
      _SaleFinancialDetailScreenState();
}

abstract class _SaleFinancialDetailScreenStateBase
    extends State<SaleFinancialDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _saleData;
  late final SaleFinancialDetailTourKeys _tourKeys;
  final ExpansibleController _firstInstallmentController =
      ExpansibleController();
  bool? _firstCuotaExpandedBeforeTour;
  bool _didAttemptAutoTour = false;

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? SaleFinancialDetailTourKeys();
    _loadData();
  }

  @override
  void dispose() {
    _firstInstallmentController.dispose();
    super.dispose();
  }

  Widget _buildInstallmentActionsRow({
    required int index,
    required Map<String, dynamic> c,
    required DateTime dueDate,
    required double cMoraMonto,
    required bool isOverdue,
    required bool isDark,
    required bool isLoan,
  });
  Widget _buildFinancialRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    required bool isDark,
  });

  Future<void> _expandFirstInstallmentForTour() async {
    if (!mounted) return;
    final cuotas = (_saleData?['cuotas'] as List<dynamic>?) ?? const [];
    if (cuotas.isEmpty) return;

    try {
      _firstCuotaExpandedBeforeTour ??= _firstInstallmentController.isExpanded;
      if (!_firstInstallmentController.isExpanded) {
        _firstInstallmentController.expand();
        await Future.delayed(const Duration(milliseconds: 280));
      }
    } catch (_) {}
  }

  Future<void> _restoreFirstInstallmentAfterTour() async {
    final prev = _firstCuotaExpandedBeforeTour;
    _firstCuotaExpandedBeforeTour = null;
    if (!mounted) return;

    try {
      if (prev == false && _firstInstallmentController.isExpanded) {
        _firstInstallmentController.collapse();
        await Future.delayed(const Duration(milliseconds: 220));
      }
    } catch (_) {}
  }

  ScreenTourConfig _buildTourConfig() {
    return SaleFinancialDetailTour.buildConfig(
      keys: _tourKeys,
      onExpandFirstInstallment: _expandFirstInstallmentForTour,
      onRestoreFirstInstallment: _restoreFirstInstallmentAfterTour,
    );
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final data = await provider.getSaleDetail(widget.saleId);

    if (mounted) {
      setState(() {
        _saleData = data;
        _isLoading = false;
      });
      if (widget.autoTriggerTour && !_didAttemptAutoTour && data != null) {
        _didAttemptAutoTour = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await InteractiveTourService.maybeStartAutomaticTour(
            context,
            _buildTourConfig(),
          );
        });
      }
    }
  }
}

class _SaleFinancialDetailScreenState
    extends _SaleFinancialDetailScreenStateBase
    with
        _SaleFinancialBalanceCardMixin,
        _SaleFinancialLogisticsDialogsMixin,
        _SaleFinancialInstallmentActionsMixin,
        _SaleFinancialInstallmentsMixin,
        _SaleFinancialItemsMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading && _saleData == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_saleData == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(),
        body: const Center(child: Text("Error cargando venta")),
      );
    }

    // Parseo double seguro desde SQLite
    final double total =
        (num.tryParse(_saleData!['monto_total'].toString()) ?? 0.0).toDouble();
    final double pagado =
        (num.tryParse(_saleData!['monto_pagado'].toString()) ?? 0.0).toDouble();
    final double interes =
        (num.tryParse(_saleData!['porcentaje_interes']?.toString() ?? '0') ??
                0.0)
            .toDouble();
    final double moraTotal =
        (num.tryParse((_saleData!['mora_total'] ?? 0.0).toString()) ?? 0.0)
            .toDouble();

    double saldo = total - pagado;
    if (saldo <= 0.02) saldo = 0.0;

    final List<dynamic> cuotas = _saleData!['cuotas'] ?? [];
    final items = _saleData!['items'] as List<dynamic>? ?? [];
    final bool isLoan = _saleData!['origen_venta'] == 'prestamo_personal';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isLoan),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.blue[800],
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReceiptButton(),
              if (!isLoan) _buildLogisticsCard(isDark, cardColor),
              _buildBalanceCard(
                isDark: isDark,
                isLoan: isLoan,
                total: total,
                pagado: pagado,
                saldo: saldo,
                interes: interes,
                moraTotal: moraTotal,
              ),
              _buildInstallmentsSection(
                cuotas,
                isDark,
                cardColor,
                textColor,
                isLoan,
              ),
              if (!isLoan)
                _buildItemsSection(items, isDark, cardColor, textColor),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLoan) {
    final seq = _saleData?['numero_secuencial'] ?? widget.saleId;
    return AppBar(
      leadingWidth: 38,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isLoan ? "Detalle del Préstamo #$seq" : "Detalle de Venta #$seq",
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        InfoTooltipButton(
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          title: "Detalle Financiero de Venta",
          description:
              "Controla el saldo pendiente, cronograma de cuotas con recargo de mora, abonos directos y envío del estado de cuenta.",
          tips: const [
            InfoTip(
              icon: Icons.expand_more_rounded,
              text:
                  "Toca cualquier cuota para desplegar su Monto Base, Mora acumulada y botones de cobro o prórroga.",
            ),
            InfoTip(
              icon: Icons.timer_outlined,
              text:
                  "En cuotas vencidas aplica mora con 'Mora' y en cuotas vigentes programa reglas automáticas con 'Prog. Mora'.",
            ),
            InfoTip(
              icon: Icons.edit_calendar_rounded,
              text:
                  "Usa 'Fecha' dentro de una cuota pendiente para reprogramar su vencimiento cuando acuerdes prórroga.",
            ),
            InfoTip(
              icon: Icons.picture_as_pdf_rounded,
              text:
                  "Comparte el cronograma en PDF o envía un recordatorio formal por WhatsApp desde la barra superior.",
            ),
          ],
          onStartInteractiveTour: () => _startTour(context),
        ),
        KeyedSubtree(
          key: _tourKeys.exportActionsKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.redAccent,
                  size: 21,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: "Ver PDF",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(
                        quotationId: _saleData?['cotizacion_id'] ?? 0,
                        saleId: widget.saleId,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.chat,
                  color: Color(0xFF25D366),
                  size: 21,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: "Enviar WhatsApp",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhatsAppPreviewScreen(
                        quotationId: _saleData?['cotizacion_id'] ?? 0,
                        saleId: widget.saleId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
