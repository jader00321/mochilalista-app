// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';

import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_header_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_client_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_notes_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_items_list.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_action_footer.dart';

import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/sale_history_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

part 'sale_history_detail/sale_history_detail_actions_part.dart';
part 'sale_history_detail/sale_history_detail_dialogs_and_notes_part.dart';

class SaleHistoryDetailScreen extends StatefulWidget {
  final int? saleId;
  final int? quotationId;
  final bool autoTriggerTour;
  final SaleHistoryDetailTourKeys? tourKeys;

  const SaleHistoryDetailScreen({
    super.key,
    this.saleId,
    this.quotationId,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<SaleHistoryDetailScreen> createState() =>
      _SaleHistoryDetailScreenState();
}

class _SaleHistoryDetailScreenState extends State<SaleHistoryDetailScreen> {
  bool _isLoading = true;
  bool _isProcessingAction = false;
  Map<String, dynamic>? _saleData;
  late final SaleHistoryDetailTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? SaleHistoryDetailTourKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSaleDetail();
    });
  }

  void _updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  ScreenTourConfig _buildTourConfig() {
    return SaleHistoryDetailTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _showSnack(String message, {bool isError = false}) {
    AppFeedbackHelper.showSnackBar(
      context,
      message,
      backgroundColor: isError ? Colors.red : Colors.green[800],
      behavior: SnackBarBehavior.floating,
    );
  }

  Future<void> _loadSaleDetail() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    Map<String, dynamic>? data;

    if (widget.saleId != null && widget.saleId! > 0) {
      data = await saleProv.getSaleDetail(widget.saleId!);
    } else if (widget.quotationId != null) {
      try {
        final sale = saleProv.salesHistory.firstWhere(
          (s) => s.quotationId == widget.quotationId,
        );
        data = await saleProv.getSaleDetail(sale.id);
      } catch (e) {
        data = null;
      }
    }

    if (mounted) {
      setState(() {
        _saleData = data;
        _isLoading = false;
      });

      if (data == null) {
        _showSnack("Error al cargar el detalle de la venta", isError: true);
      } else if (widget.autoTriggerTour && !_didAttemptAutoTour) {
        _didAttemptAutoTour = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          await InteractiveTourService.maybeStartAutomaticTour(
            context,
            _buildTourConfig(),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_saleData == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Detalle")),
        body: const Center(child: Text("Error al cargar datos.")),
      );
    }

    final items = _saleData!['items'] as List<dynamic>? ?? [];
    final origenVenta = _saleData!['origen_venta'];
    final styles = _getOrigenStyles(origenVenta, isDark);

    final String dateString = _saleData!['fecha_venta'] != null
        ? AppDateFormatter.ddMMyyyyHhmma.format(
            DateTime.parse(_saleData!['fecha_venta']),
          )
        : "";

    final bool isQuickSale = origenVenta == 'pos_rapido';
    final bool isLoan = origenVenta == 'prestamo_personal';
    final int cotizacionId = _saleData!['cotizacion_id'] ?? 0;
    final int? clientId = _saleData!['cliente_id'];
    final int effectiveSaleId =
        widget.saleId ?? (_saleData!['id'] as int? ?? 0);

    final Map<String, dynamic>? cotizacion =
        _saleData!['cotizacion'] as Map<String, dynamic>?;
    final String institution = cotizacion?['institution_name'] ?? "";
    final String grade = cotizacion?['grade_level'] ?? "";
    const String imageUrl = "";

    final String clientNote = _saleData!['cliente_notas'] ?? "";
    final String saleNote = isLoan
        ? (_saleData!['nota_prestamo'] ?? "")
        : (cotizacion?['notas'] ?? _saleData!['nota_prestamo'] ?? "");

    final double totalAmount = (_saleData!['monto_total'] ?? 0).toDouble();
    final double paidAmount = (_saleData!['monto_pagado'] ?? 0).toDouble();

    double pendingDebt = totalAmount - paidAmount;
    if (pendingDebt < 0) {
      pendingDebt = 0;
    }

    final List<dynamic> cuotasRaw = _saleData!['cuotas'] ?? [];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          try {
            Provider.of<SaleProvider>(context, listen: false).silentRefresh();
          } catch (_) {}
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              leadingWidth: 38,
              titleSpacing: 0,
              actionsPadding: EdgeInsets.zero,
              title: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isLoan
                        ? "Préstamo #${_saleData!['numero_secuencial'] ?? _saleData!['id']}"
                        : "Recibo #${_saleData!['numero_secuencial'] ?? _saleData!['id']}",
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      fontSize: 19,
                    ),
                  ),
                ),
              ),
              backgroundColor: bgColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              actions: [
                InfoTooltipButton(
                  iconColor: isDark ? Colors.grey[400] : Colors.grey[700],
                  iconSize: 20,
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  onStartInteractiveTour: () => _startTour(context),
                  title: "Detalle de Comprobante",
                  description:
                      "Consulta el resumen completo de la venta o préstamo, los artículos entregados, notas internas y opciones de impresión, WhatsApp o anulación segura.",
                  tips: const [
                    InfoTip(
                      icon: Icons.note_add_outlined,
                      text:
                          "Añade o edita notas rápidas sin alterar montos ni cantidades entregadas.",
                    ),
                    InfoTip(
                      icon: Icons.print_outlined,
                      text:
                          "Desde PDF o WhatsApp en la barra inferior puedes reimprimir ticket Bluetooth o enviar el comprobante.",
                    ),
                    InfoTip(
                      icon: Icons.security_outlined,
                      text:
                          "Usa el menú superior para anular con reversión automática de stock si corresponde.",
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.note_add, size: 21),
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  tooltip: "Añadir o Editar Notas",
                  onPressed: () => _showAddNoteMenu(
                    cotizacionId: cotizacionId,
                    clientId: clientId,
                    currentSaleNote: saleNote,
                    currentClientNote: clientNote,
                    isDark: isDark,
                    isLoan: isLoan,
                    saleId: effectiveSaleId,
                  ),
                ),
                KeyedSubtree(
                  key: _tourKeys.cancelMenuKey,
                  child: PopupMenuButton<String>(
                    color: isDark ? const Color(0xFF23232F) : Colors.white,
                    padding: const EdgeInsets.all(5),
                    icon: Icon(Icons.more_vert, color: textColor, size: 22),
                    onSelected: (val) {
                      if (val == 'archive') {
                        _handleArchive(isDark);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(
                              _saleData!['is_archived'] == 1
                                  ? Icons.unarchive
                                  : Icons.auto_delete,
                              color: _saleData!['is_archived'] == 1
                                  ? (isDark ? Colors.green[400] : Colors.green)
                                  : (isDark ? Colors.red[400] : Colors.red),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _saleData!['is_archived'] == 1
                                  ? (isLoan
                                        ? "Restaurar Préstamo"
                                        : "Restaurar Venta")
                                  : (isLoan
                                        ? "Anular Préstamo"
                                        : "Anular Venta"),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  KeyedSubtree(
                    key: _tourKeys.headerSummaryKey,
                    child: DetailHeaderCard(
                      saleData: _saleData!,
                      styles: styles,
                      totalAmount: totalAmount,
                      dateString: dateString,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DetailClientCard(
                    saleData: _saleData!,
                    isQuickSale: isQuickSale,
                    institution: institution,
                    grade: grade,
                    isDark: isDark,
                    clientId: _saleData!['cliente_id'],
                  ),
                  DetailNotesCard(
                    saleNote: saleNote,
                    clientNote: clientNote,
                    cotizacionId: cotizacionId,
                    clientId: clientId,
                    saleId: effectiveSaleId,
                    isDark: isDark,
                    isLoan: isLoan,
                    onEditTap: (type, currentNote, id) => _showEditNoteDialog(
                      type: (isLoan || type == 'loan') ? 'loan' : type,
                      currentNote: currentNote,
                      id: (isLoan || type == 'loan') ? effectiveSaleId : id,
                    ),
                  ),
                  KeyedSubtree(
                    key: isLoan ? _tourKeys.itemsDetailKey : null,
                    child: DetailStatusCard(
                      saleData: _saleData!,
                      totalAmount: totalAmount,
                      paidAmount: paidAmount,
                      pendingDebt: pendingDebt,
                      cuotasRaw: cuotasRaw,
                      isDark: isDark,
                      onPaymentSuccess: _loadSaleDetail,
                    ),
                  ),
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Card(
                        elevation: 0,
                        color: isDark
                            ? Colors.purple.withValues(alpha: 0.15)
                            : Colors.purple.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.purple.withValues(alpha: 0.3)
                                : Colors.purple.shade200,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Icon(
                            Icons.image,
                            color: isDark ? Colors.purple[200] : Colors.purple,
                            size: 30,
                          ),
                          title: Text(
                            "Ver lista física escaneada",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.purple[100]
                                  : Colors.purple,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 20,
                            color: isDark ? Colors.purple[200] : Colors.purple,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: imageUrl,
                                tag: "evidence_${_saleData!['id']}",
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!isLoan)
                    KeyedSubtree(
                      key: _tourKeys.itemsDetailKey,
                      child: SaleItemsList(
                        items: items,
                        isDark: isDark,
                        cardColor: cardColor,
                        textColor: textColor,
                      ),
                    ),
                  SizedBox(
                    height:
                        kBottomNavigationBarHeight +
                        MediaQuery.of(context).padding.bottom +
                        60,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: KeyedSubtree(
              key: _tourKeys.footerEmitKey,
              child: SaleActionFooter(
                isDark: isDark,
                cardColor: cardColor,
                cotizacionId: cotizacionId,
                saleId: widget.saleId,
                isQuickSale: isQuickSale,
                isLoan: isLoan,
                pendingDebt: pendingDebt,
                onSellAgainQuickSale: () => _handleSellAgainQuickSale(isDark),
                onDuplicateOptions: () =>
                    _showDuplicateOptionsModal(cotizacionId, isDark),
                onRegisterPayment: _handleRegisterPayment,
              ),
            ),
          ),
          if (_isProcessingAction)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 24),
                    Text(
                      "Procesando...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
