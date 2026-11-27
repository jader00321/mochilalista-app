import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';

import 'package:app_movil/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_item_row.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_product_search_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/suggested_replacements_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_smart_bottom_bar.dart';

import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_client_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/client_orders_screen.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/matching_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

part 'matching/matching_header_accordions_mixin.dart';
part 'matching/matching_items_list_mixin.dart';
part 'matching/matching_flow_and_actions_mixin.dart';
part 'matching/matching_item_modals_mixin.dart';

class MatchingScreen extends StatefulWidget {
  final List<ExtractedItem> extractedItems;
  final ExtractedMetadata? metadata;
  final bool prioritizeWholesale;
  final bool autoTriggerTour;
  final MatchingTourKeys? tourKeys;

  const MatchingScreen({
    super.key,
    required this.extractedItems,
    this.metadata,
    this.prioritizeWholesale = false,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

abstract class _MatchingScreenBase extends State<MatchingScreen> {
  late TextEditingController _schoolCtrl;
  late TextEditingController _gradeCtrl;
  late QuotationContextMode _currentMode;

  var _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientDniCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientNotesCtrl = TextEditingController();

  final _quoteTitleCtrl = TextEditingController();
  final _quoteNotesCtrl = TextEditingController();

  bool _updateClientData = true;
  bool _isQuoteDataExpanded = false;
  bool _isClientPanelExpanded = false;
  bool _isAutoTitleMode = true;
  bool _isGeneratingTitle = false;
  late final MatchingTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;
  bool? _clientExpandedBeforeTour;
  bool? _quoteExpandedBeforeTour;

  Future<void> _expandClientPanelForTour();
  Future<void> _restoreClientPanelAfterTour();
  Future<void> _expandQuoteDataForTour();
  Future<void> _restoreQuoteDataAfterTour();
  void _syncAutoTitle({bool force = false});
  void _restoreAutoTitle();
  void _updateHeader();
  void _clearClient();
  void _showClientSearch(bool isDark);
  Future<void> _openDetailsModal(BuildContext context, MatchPair pair);
  void _openSearchModal(BuildContext context, MatchPair pair, bool isDark);
  void _openSuggestedReplacementsModal(
    BuildContext context,
    MatchPair pair,
    bool isDark,
  );
  void _confirmAndDeletePair(BuildContext context, MatchPair pair, bool isDark);
}

class _MatchingScreenState extends _MatchingScreenBase
    with
        _MatchingHeaderAccordionsMixin,
        _MatchingItemsListMixin,
        _MatchingFlowAndActionsMixin,
        _MatchingItemModalsMixin {
  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? MatchingTourKeys();

    final provider = Provider.of<MatchingProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;
    final mode =
        widget.metadata?.contextMode ??
        provider.metadata?.contextMode ??
        (widget.prioritizeWholesale
            ? QuotationContextMode.wholesale
            : QuotationContextMode.general);
    _currentMode = mode;

    String initSchool = widget.metadata?.institutionName ?? "";
    String initClient = widget.metadata?.studentName ?? "";
    String initGrade = widget.metadata?.gradeLevel ?? "";

    // VINCULACIÓN VISUAL DEL CLIENTE VIP
    if (isClient) {
      initClient = auth.user?.fullName ?? initClient;
      _clientPhoneCtrl.text = auth.user?.phone ?? "";
      _clientEmailCtrl.text = auth.user?.email ?? "";

      final mySelf = ClientModel(
        id: 0,
        negocioId: 0,
        creadoPorUsuarioId: 0,
        usuarioVinculadoId: auth.user?.id,
        fullName: auth.user?.fullName ?? "Mi Cuenta",
        phone: auth.user?.phone ?? "",
        registeredDate: DateTime.now().toIso8601String(),
      );
      provider.setClient(mySelf);
    }

    if (provider.pairs.isNotEmpty) {
      initSchool = provider.metadata?.institutionName ?? initSchool;
      initClient =
          provider.selectedClient?.fullName ??
          provider.metadata?.studentName ??
          initClient;
      initGrade = provider.metadata?.gradeLevel ?? initGrade;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeStartAutoTour();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await provider.initializeAndMatch(
          widget.extractedItems,
          widget.metadata,
          isClientRole: isClient,
          prioritizeWholesale: widget.prioritizeWholesale,
        );
        if (mounted) _maybeStartAutoTour();
      });
    }

    _schoolCtrl = TextEditingController(text: initSchool);
    _gradeCtrl = TextEditingController(text: initGrade);
    _clientNameCtrl = TextEditingController(text: initClient);

    final initialTitle = QuotationNamingEngine.generateTitle(
      selectedClient: provider.selectedClient,
      typedClientName: initClient,
      schoolName: initSchool,
      gradeLevel: initGrade,
      quotationType: 'ai_scan',
      isClientRole: isClient,
      clientUserName: auth.user?.fullName,
      contextMode: _currentMode,
    );
    _quoteTitleCtrl.text = initialTitle;

    _clientNameCtrl.addListener(() {
      _updateHeader();
      if (_isAutoTitleMode) _syncAutoTitle();
    });
    _schoolCtrl.addListener(() {
      _updateHeader();
      if (_isAutoTitleMode) _syncAutoTitle();
    });
    _gradeCtrl.addListener(() {
      _updateHeader();
      if (_isAutoTitleMode) _syncAutoTitle();
    });
    _quoteTitleCtrl.addListener(() {
      if (!_isGeneratingTitle && _isAutoTitleMode) {
        setState(() => _isAutoTitleMode = false);
      }
    });
  }

  @override
  void dispose() {
    _quoteTitleCtrl.dispose();
    _quoteNotesCtrl.dispose();
    _schoolCtrl.dispose();
    _gradeCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientDniCtrl.dispose();
    _clientAddressCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingProvider = Provider.of<MatchingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textTheme = Theme.of(context).textTheme;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = !authProv.hasActiveContext;
    final isClient = authProv.isCommunityClient;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await InteractiveTourService.cancelActiveTour()) return;
        if (!context.mounted) return;
        final shouldPop = await _onWillPop(isDark);
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          titleSpacing: 0,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isClient ? "Completar mi Pedido" : "Cotización Inteligente",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          actions: [
            InfoTooltipButton(
              iconColor: Colors.white,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
              onStartInteractiveTour: () => _startTour(context),
              title: "Cotización Inteligente IA",
              description:
                  "Revisa y ajusta los artículos conciliados por la IA, añade filas manuales, configura cliente o colegio y cierra la venta o proforma.",
              tips: const [
                InfoTip(
                  icon: Icons.touch_app_rounded,
                  text:
                      "Toca cualquier fila emparejada para cambiar presentación, precio o ver equivalentes sugeridos.",
                ),
                InfoTip(
                  icon: Icons.expand_more_rounded,
                  text:
                      "Despliega los paneles superiores para elegir modo General, Mayorista o Escolar y añadir notas.",
                ),
              ],
            ),
            if (matchingProvider.hasModifications)
              IconButton(
                icon: Icon(
                  Icons.settings_backup_restore,
                  color: isDark ? Colors.orange[300] : Colors.orangeAccent,
                  size: 22,
                ),
                tooltip: "Reiniciar Análisis",
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(6),
                onPressed: () => _resetToInitial(isDark),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 10.0, left: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "${matchingProvider.matchedCount}/${matchingProvider.pairs.length} Listos",
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildEditableHeader(
                          matchingProvider,
                          isDark,
                          textTheme,
                          isGuest,
                          isClient,
                        ),
                      ),
                      if (matchingProvider.isLoading)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (matchingProvider.pairs.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildEmptyMatchedCard(isDark),
                        )
                      else
                        _buildMatchedItemsSliver(
                          matchingProvider,
                          isDark,
                          isClient,
                        ),
                      if (!matchingProvider.isLoading && !isClient)
                        _buildManualAddSliver(
                          matchingProvider,
                          isDark,
                          textTheme,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
                KeyedSubtree(
                  key: _tourKeys.bottomBarKey,
                  child: MatchingSmartBottomBar(
                    provider: matchingProvider,
                    isDark: isDark,
                    theme: textTheme,
                    isClient: isClient,
                    isEnabled:
                        !matchingProvider.isLoading &&
                        matchingProvider.pairs.isNotEmpty,
                    onActionTap: () {
                      if (isClient) {
                        _handleActionWithConfirmation('client_send', isDark);
                      } else {
                        MatchingActionsBottomSheet.show(
                          context,
                          isDark: isDark,
                          onActionSelected: (actionType) =>
                              _handleActionWithConfirmation(actionType, isDark),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            if (matchingProvider.isSaving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
