import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/tour/configs/invoice_staging_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/staging_product_group_card.dart';
import 'package:app_movil/features/scanner/widgets/staging/staging_vendor_card.dart';

part 'invoice_staging/invoice_staging_dialogs_and_actions_mixin.dart';
part 'invoice_staging/invoice_staging_sections_and_scroll_mixin.dart';

/// Pantalla de revisión, clasificación y confirmación de factura al inventario.
class InvoiceStagingScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final InvoiceStagingTourKeys? tourKeys;

  const InvoiceStagingScreen({
    super.key,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<InvoiceStagingScreen> createState() => _InvoiceStagingScreenState();
}

abstract class _InvoiceStagingScreenBase extends State<InvoiceStagingScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _groupKeys = {};
  bool _showScrollToTop = false;
  late final InvoiceStagingTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;

  void _scrollToFirstStockConflict(ScannerProvider provider);

  void _scrollToConflictGroup(ScannerProvider provider, String groupUuid);

  void _showStockErrorModal(BuildContext context, ScannerProvider provider);

  void _confirmSave(BuildContext context, ScannerProvider provider);
}

class _InvoiceStagingScreenState extends _InvoiceStagingScreenBase
    with
        _InvoiceStagingDialogsAndActionsMixin,
        _InvoiceStagingSectionsAndScrollMixin {
  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? InvoiceStagingTourKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      invProv.loadCategories();
      invProv.loadBrands();
      invProv.loadMasterData();
      invProv.loadInventory(reset: true);
      _maybeStartAutoTour();
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return InvoiceStagingTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _maybeStartAutoTour() {
    if (!widget.autoTriggerTour || _didAttemptAutoTour || !mounted) {
      return;
    }
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    if (provider.stagingData == null) {
      return;
    }
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScannerProvider>(context);
    final staging = provider.stagingData;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (staging == null) {
      return _buildRestoringScaffold(isDark, bgColor);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (await InteractiveTourService.cancelActiveTour()) {
          return;
        }
        if (!context.mounted) {
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(context, provider, isDark),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildProgressHeaderBar(provider, isDark),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: staging.productosAgrupados.length + 2,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return KeyedSubtree(
                            key: _tourKeys.vendorCardKey,
                            child: StagingVendorCard(
                              provider: provider,
                              staging: staging,
                              isDark: isDark,
                            ),
                          );
                        }

                        if (i == staging.productosAgrupados.length + 1) {
                          return _buildAddManualGroupButton(
                            provider,
                            isDark,
                            staging.productosAgrupados.isEmpty,
                          );
                        }

                        final groupIndex = i - 1;
                        final group = staging.productosAgrupados[groupIndex];
                        final groupKey = _groupKeys.putIfAbsent(
                          group.uuidTemporal,
                          () => GlobalKey(),
                        );

                        final cardWidget = KeyedSubtree(
                          key: groupKey,
                          child: StagingProductGroupCard(
                            key: ValueKey(group.uuidTemporal),
                            groupIndex: groupIndex,
                            provider: provider,
                            isDark: isDark,
                          ),
                        );

                        if (groupIndex == 0) {
                          return KeyedSubtree(
                            key: _tourKeys.productGroupsKey,
                            child: cardWidget,
                          );
                        }
                        return cardWidget;
                      },
                    ),
                  ),
                ],
              ),
              if (_showScrollToTop)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: _scrollToTop,
                    backgroundColor: isDark
                        ? Colors.blueGrey[800]
                        : Colors.white,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 4,
                    child: const Icon(Icons.keyboard_arrow_up, size: 24),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomCommitBar(provider, isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ScannerProvider provider,
    bool isDark,
  ) {
    return AppBar(
      titleSpacing: 0,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          "Clasificar y Confirmar",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      backgroundColor: isDark
          ? const Color(0xFF1A1A24)
          : const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        InfoTooltipButton(
          iconColor: Colors.white,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(6),
          onStartInteractiveTour: () => _startTour(context),
          title: "Clasificación en Inventario",
          description:
              "Vincula proveedor y agrupa variantes de la factura con productos existentes o nuevos antes de guardar el stock.",
          tips: const [
            InfoTip(
              icon: Icons.tune_rounded,
              text:
                  "Edita presentaciones, costos y precios de venta en cada bloque antes del ingreso final.",
            ),
            InfoTip(
              icon: Icons.save_alt_rounded,
              text:
                  "El guardado registra factura, costos e ingreso de unidades de forma atómica.",
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.restore_page, size: 24),
          tooltip: "Deshacer cambios y restaurar",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          padding: const EdgeInsets.all(6),
          onPressed: provider.isLoading ? null : _confirmResetProcess,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildAddManualGroupButton(
    ScannerProvider provider,
    bool isDark,
    bool attachProductGroupsKey,
  ) {
    final manualBtn = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: () => provider.addNewProductGroup(),
        icon: const Icon(Icons.add, size: 24),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "AGREGAR PRODUCTO MANUALMENTE",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
          side: BorderSide(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.5)
                : Colors.blue.shade800,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: isDark
              ? Colors.blue.withValues(alpha: 0.05)
              : Colors.white,
        ),
      ),
    );
    if (attachProductGroupsKey) {
      return KeyedSubtree(key: _tourKeys.productGroupsKey, child: manualBtn);
    }
    return manualBtn;
  }
}
