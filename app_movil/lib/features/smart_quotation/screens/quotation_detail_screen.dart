import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';

import 'package:app_movil/features/smart_quotation/widgets/smart_update_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_detail_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_evidence_panel.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_item_list_row.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quotation_action_buttons.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/quotation_detail_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

part 'quotation_detail/quotation_detail_validation_mixin.dart';
part 'quotation_detail/quotation_detail_dialogs_mixin.dart';
part 'quotation_detail/quotation_detail_state_sheet_mixin.dart';
part 'quotation_detail/quotation_detail_header_and_banners.dart';

class QuotationDetailScreen extends StatefulWidget {
  final int quotationId;
  final String? clientName;
  final bool autoTriggerTour;
  final QuotationDetailTourKeys? tourKeys;

  const QuotationDetailScreen({
    super.key,
    required this.quotationId,
    this.clientName,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

abstract class _QuotationDetailScreenStateBase
    extends State<QuotationDetailScreen> {
  bool _isLoading = true;
  SmartQuotationModel? _fullQuotation;
  late final QuotationDetailTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? QuotationDetailTourKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return QuotationDetailTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );
    final quotationProv = Provider.of<SmartQuotationProvider>(
      context,
      listen: false,
    );
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      _fullQuotation = await quotationProv.getQuotationById(widget.quotationId);

      // Solo el equipo del negocio valida el semáforo de inventario
      if (!auth.isCommunityClient) {
        await workbenchProv.checkTrafficLight(widget.quotationId);

        if (mounted &&
            _fullQuotation != null &&
            _fullQuotation!.status == 'READY') {
          final validation = workbenchProv.getValidationFor(widget.quotationId);
          if (validation != null && !validation.canSell) {
            await _changeStatus('PENDING', isAutoRevert: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al cargar: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.autoTriggerTour &&
            !_didAttemptAutoTour &&
            _fullQuotation != null) {
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
  }

  void _handleUpdateAnalysis(ValidationResult validation);
  Future<void> _downloadImage();
  Future<void> _changeStatus(String newStatus, {bool isAutoRevert = false});
  void _confirmConvertToPack(WorkbenchProvider provider);
  void _handleDeleteRequest();
  void _showQuotationNameDialog(bool isDark);
  void _showRenameDialog(bool isDark);
  void _showTextEvidenceDialog(bool isDark);
  void _showStateSelectorModal(bool isDark);
  Widget _buildSmartAlertBanner(ValidationResult validation, bool isDark);
  Color _getStatusColor(String status, bool isDark, bool isClient);
  String _getStatusText(String status, bool isClient);

  @override
  Widget build(BuildContext context) {
    final workbenchProv = Provider.of<WorkbenchProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isClient = auth.isCommunityClient;

    final validation = workbenchProv.getValidationFor(widget.quotationId);
    final items = _fullQuotation?.items ?? [];

    // Ocultar evidencia IA si el pedido fue manual
    final bool isAiScan = _fullQuotation?.type == 'ai_scan';
    final bool hasImage =
        _fullQuotation?.sourceImageUrl != null &&
        _fullQuotation!.sourceImageUrl!.isNotEmpty;
    final bool hasTextEvidence =
        (_fullQuotation?.originalTextDump != null &&
            _fullQuotation!.originalTextDump!.isNotEmpty) ||
        items.any((i) => i.originalText != null && i.originalText!.isNotEmpty);

    // Solo mostrar evidencia si hubo escaneo con IA o se adjuntó imagen.
    final bool showEvidence = isAiScan || hasImage;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    final bool hasAlertBanner =
        !isClient &&
        validation != null &&
        (validation.hasIssues || !validation.canSell) &&
        _fullQuotation?.status != 'SOLD';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leadingWidth: 36,
        titleSpacing: 0,
        actionsPadding: EdgeInsets.zero,
        title: Column(
          key: _tourKeys.titleStatusKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 24,
              child: MarqueeText(
                text:
                    _fullQuotation?.clientName ??
                    widget.clientName ??
                    "Detalle",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                onTap: () => _showQuotationNameDialog(isDark),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      _fullQuotation?.status ?? 'DRAFT',
                      isDark,
                      isClient,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getStatusText(_fullQuotation?.status ?? 'DRAFT', isClient),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: isDark
            ? const Color(0xFF1A1A24)
            : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          InfoTooltipButton(
            iconColor: Colors.white70,
            iconSize: 19,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onStartInteractiveTour: () => _startTour(context),
            title: "Detalle de Cotización",
            description:
                "Revisa los ítems cotizados, valida el inventario antes de vender, oculta tus costos en Modo Privacidad y exporta en PDF o WhatsApp.",
            tips: const [
              InfoTip(
                icon: Icons.edit_note_rounded,
                text:
                    "Toca el título en la barra superior si deseas renombrar la lista para tu cliente.",
              ),
              InfoTip(
                icon: Icons.visibility_off_outlined,
                text:
                    "El botón de ojo oculta precios de costo y utilidades cuando enseñas la pantalla en mostrador.",
              ),
              InfoTip(
                icon: Icons.point_of_sale_rounded,
                text:
                    "Usa los botones inferiores para editar la lista, enviar PDF/WhatsApp o convertirla en venta.",
              ),
            ],
          ),
          Consumer<QuickSaleProvider>(
            builder: (ctx, quickProv, _) => KeyedSubtree(
              key: _tourKeys.privacyAndEditKey,
              child: IconButton(
                icon: Icon(
                  quickProv.hideProfits
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.white70,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: quickProv.hideProfits
                    ? "Modo Cliente (Privacidad activa)"
                    : "Modo Vendedor",
                onPressed: () => quickProv.toggleHideProfits(),
              ),
            ),
          ),
          if (_fullQuotation?.status != 'SOLD')
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: "Sincronizar",
              onPressed: _loadData,
            ),
          if (!isClient)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: "Opciones y Estado",
              onPressed: () => _showStateSelectorModal(isDark),
            ),
          const SizedBox(width: 2),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                if (hasAlertBanner)
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _tourKeys.stockAlertOrItemsKey,
                      child: _buildSmartAlertBanner(validation, isDark),
                    ),
                  ),
                if (_fullQuotation?.status == 'SOLD')
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isClient
                                  ? "¡COMPRA CONFIRMADA Y PROCESADA!"
                                  : "LISTA VENDIDA Y CERRADA",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPersistentHeader(
                  pinned: false,
                  floating: true,
                  delegate: _QuoteHeaderDelegate(
                    quotation: _fullQuotation,
                    fallbackClientName: widget.clientName,
                    isDark: isDark,
                    summaryKey: _tourKeys.totalsSummaryKey,
                    textScale: MediaQuery.textScalerOf(
                      context,
                    ).scale(1.0).clamp(1.0, 2.0),
                  ),
                ),
                if (showEvidence)
                  SliverToBoxAdapter(
                    child: QuoteEvidencePanel(
                      hasImage: hasImage,
                      hasText: hasTextEvidence,
                      imageUrl: _fullQuotation?.sourceImageUrl,
                      isDark: isDark,
                      onImageTap: () {
                        if (_fullQuotation?.sourceImageUrl != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: _fullQuotation!.sourceImageUrl!,
                                tag: "${_fullQuotation!.id}_evidence",
                              ),
                            ),
                          );
                        }
                      },
                      onDownloadTap: _downloadImage,
                      onTextEvidenceTap: () => _showTextEvidenceDialog(isDark),
                    ),
                  ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Container(
                        key: !hasAlertBanner
                            ? _tourKeys.stockAlertOrItemsKey
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Text(
                          "No hay productos en esta cotización",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: 120 + MediaQuery.of(context).padding.bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final item = items[i];
                        final stockWarning = isClient
                            ? null
                            : validation?.stockWarnings.firstWhere(
                                (w) => w.itemId == item.id,
                                orElse: () => StockWarning(
                                  itemId: -1,
                                  productName: "",
                                  requested: 0,
                                  available: 0,
                                ),
                              );
                        final priceChange = isClient
                            ? null
                            : validation?.priceChanges.firstWhere(
                                (p) => p.itemId == item.id,
                                orElse: () => PriceChange(
                                  itemId: -1,
                                  productName: "",
                                  oldPrice: 0,
                                  newPrice: 0,
                                ),
                              );

                        SharedStockConflict? sharedConflict;
                        QuoteItemConflictDetail? sharedConflictDetail;
                        if (!isClient && validation != null) {
                          for (final conflict
                              in validation.sharedStockConflicts) {
                            final match = conflict.conflictingItems
                                .where((c) => c.itemId == item.id)
                                .firstOrNull;
                            if (match != null) {
                              sharedConflict = conflict;
                              sharedConflictDetail = match;
                              break;
                            }
                          }
                        }

                        return KeyedSubtree(
                          key: (!hasAlertBanner && i == 0)
                              ? _tourKeys.stockAlertOrItemsKey
                              : null,
                          child: QuoteItemListRow(
                            item: item,
                            stockError: stockWarning,
                            priceError: priceChange,
                            sharedConflict: sharedConflict,
                            sharedConflictDetail: sharedConflictDetail,
                            isDark: isDark,
                          ),
                        );
                      }, childCount: items.length),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: KeyedSubtree(
        key: _tourKeys.outputActionsKey,
        child: QuotationActionButtons(
          quotationId: widget.quotationId,
          status: _fullQuotation?.status ?? 'DRAFT',
          validation: validation,
          isDark: isDark,
          isClient: isClient,
          onReloadData: _loadData,
          onHandleUpdateAnalysis: _handleUpdateAnalysis,
        ),
      ),
    );
  }
}

class _QuotationDetailScreenState extends _QuotationDetailScreenStateBase
    with
        _QuotationDetailValidationMixin,
        _QuotationDetailDialogsMixin,
        _QuotationDetailStateSheetMixin,
        _QuotationDetailHeaderAndBannersMixin {}
