import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/configs/manual_quotation_tour.dart';

// Providers y Servicios
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

// Widgets Modulares
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/catalog_search_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_item_card.dart';        
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_footer.dart';             
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_save_modal.dart';         
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_empty_state.dart';        
import 'package:app_movil/core/widgets/info_tooltip_button.dart';        
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_headers_section.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_dialog_helper.dart'; 

// Pantallas Destino
import 'package:app_movil/features/smart_quotation/screens/sales_checkout_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/client_orders_screen.dart';

part 'manual/manual_quote_data_ext.dart';
part 'manual/manual_quote_client_ext.dart';
part 'manual/manual_quote_save_ext.dart';
part 'manual/manual_quote_catalog_ext.dart';
part 'manual/manual_quote_offers_ext.dart';

class ManualQuotationScreen extends StatefulWidget {
  final int? quotationId; 
  final SmartQuotationModel? quotationSnapshot; 
  final List<MatchedProduct>? initialItems; 
  final Map<int, int>? initialQuantities; 
  final ClientModel? preselectedClient;

  const ManualQuotationScreen({
    super.key, 
    this.quotationId,
    this.quotationSnapshot,
    this.initialItems,
    this.initialQuantities,
    this.preselectedClient,
  });

  @override
  State<ManualQuotationScreen> createState() => _ManualQuotationScreenState();
}

class _ManualQuotationScreenState extends State<ManualQuotationScreen> {
  List<MatchedProduct> _items = [];
  final Map<int, int> _quantities = {}; 
  final Map<int, double> _overriddenPrices = {}; 
  final Map<int, String> _customNames = {}; 
  
  int? _currentQuotationId;
  ClientModel? _selectedClient;
  bool _updateClientData = true; 
  bool _isLoading = false;
  bool _isSaving = false;
  int _outdatedItemsCount = 0;
  
  bool _isQuoteDataExpanded = false; 
  bool _isClientPanelExpanded = false;
  bool? _quoteExpandedBeforeTour;
  bool? _clientExpandedBeforeTour;
  bool _hasUnsavedChanges = false;
  bool _isOffersExpanded = false;
  final _tourKeys = ManualQuotationTourKeys();
  final _footerKey = GlobalKey<ManualQuoteFooterState>();

  late final NumberFormat _currency;
  final _quoteTitleCtrl = TextEditingController();
  final _quoteNotesCtrl = TextEditingController();

  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientDniCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientNotesCtrl = TextEditingController();
  
  final _schoolCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  
  bool _isGeneratingName = false;
  bool _isAutoTitleMode = true;
  bool _isAppOrder = false;

  void _restoreAutoTitle() {
    setState(() => _isAutoTitleMode = true);
    _generateDynamicName(force: true);
  }

  @override
  void initState() {
    super.initState();
    _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    _currentQuotationId = widget.quotationId;

    if (widget.preselectedClient != null) {
      _selectedClient = widget.preselectedClient;
      _clientNameCtrl.text = widget.preselectedClient!.fullName;
      _clientPhoneCtrl.text = widget.preselectedClient!.phone;
      _clientDniCtrl.text = widget.preselectedClient!.docNumber ?? "";
      _clientAddressCtrl.text = widget.preselectedClient!.address ?? "";
      _clientEmailCtrl.text = widget.preselectedClient!.email ?? "";
      _clientNotesCtrl.text = widget.preselectedClient!.notes ?? "";
      _isClientPanelExpanded = true;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isCommunityClient) {
        _clientNameCtrl.text = auth.user?.fullName ?? "";
        _clientEmailCtrl.text = auth.user?.email ?? "";
        
        if (_quoteTitleCtrl.text.isEmpty && _currentQuotationId == null) {
            final String name = (auth.user?.fullName != null && auth.user!.fullName.isNotEmpty) ? auth.user!.fullName : "Cliente";
            _quoteTitleCtrl.text = QuotationNamingEngine.generateTitle(
              isClientRole: true,
              clientUserName: name,
              quotationType: 'manual',
            );
        }
      }
    });
    
    _clientNameCtrl.addListener(() {
      _markChanged();
      if (_isAutoTitleMode) {
        _generateDynamicName();
      }
      if (_selectedClient == null && _clientNameCtrl.text.isNotEmpty) {
        if (!_updateClientData) setState(() => _updateClientData = true);
      }
    });

    _quoteTitleCtrl.addListener(() {
      _markChanged();
      if (!_isGeneratingName && _isAutoTitleMode) {
        setState(() => _isAutoTitleMode = false);
      }
    });

    _quoteNotesCtrl.addListener(_markChanged);

    _schoolCtrl.addListener(() {
      _markChanged();
      if (_isAutoTitleMode) {
        _generateDynamicName();
      }
    });

    _gradeCtrl.addListener(() {
      _markChanged();
      if (_isAutoTitleMode) {
        _generateDynamicName();
      }
    });
    
    _initData();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _handlePullToRefresh() async {
    try {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      final promoProv = Provider.of<PromotionProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.activeBusinessId != null) {
        await promoProv.loadPromotions(auth.activeBusinessId!);
      }

      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.bundleId == null) {
          final prod = await invProv.fetchProductById(item.productId);
          if (prod != null) {
            final pres = prod.presentaciones.where((p) => p.id == item.presentationId).firstOrNull;
            if (pres != null) {
              final factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
              final newOffer = pres.hasOffer ? pres.effectivePrice : null;
              final updatedItem = item.copyWith(
                stock: pres.stockActual ~/ factor,
                price: pres.precioVentaFinal,
                offerPrice: newOffer,
                cupoMaximoVariante: pres.cupoMaximoVariante,
                clearCupo: pres.cupoMaximoVariante == null,
              );
              _items[i] = updatedItem;
              if (_overriddenPrices.containsKey(item.presentationId)) {
                if ((_overriddenPrices[item.presentationId]! - item.effectivePrice).abs() < 0.01) {
                  _overriddenPrices[item.presentationId] = updatedItem.effectivePrice;
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {});
        CustomSnackBar.show(
          context,
          message: "Catálogo y cotización sincronizados.",
          isError: false,
          icon: Icons.sync,
        );
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Para guardar esta cotización o enviarla a la caja, necesitas registrar tu propio negocio.\n\n"
          "Dirígete a tu Perfil cuando estés listo para empezar a vender.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }
  
  void _generateDynamicName({bool force = false}) async {
    if (_isGeneratingName) return;
    if (!_isAutoTitleMode && !force) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _isGeneratingName = true;
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);

    final newName = await prov.generateDynamicQuoteName(
      _selectedClient,
      _clientNameCtrl.text,
      schoolName: _schoolCtrl.text,
      gradeLevel: _gradeCtrl.text,
      isClientRole: auth.isCommunityClient,
      clientUserName: auth.user?.fullName,
      type: 'manual',
    );

    if (mounted && _quoteTitleCtrl.text != newName) {
      _quoteTitleCtrl.text = newName;
      _isAutoTitleMode = true;
    }
    _isGeneratingName = false;
  }

  Map<int, int> _computeSharedDemand() {
    final Map<int, int> demand = {};
    for (final it in _items) {
      if (it.usaStockCompartido && it.productId > 0) {
        final q = _quantities[it.presentationId] ?? 1;
        final f = it.conversionFactor > 0 ? it.conversionFactor : 1;
        demand[it.productId] = (demand[it.productId] ?? 0) + (q * f);
      }
    }
    return demand;
  }

  SmartQuotationProvider? _smartQuotationProv;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _smartQuotationProv = Provider.of<SmartQuotationProvider>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    final prov = _smartQuotationProv;
    if (prov != null) {
      if (_items.isNotEmpty && !_isSaving) {
        final itemsSnapshot = List<MatchedProduct>.from(_items);
        final quantitiesSnapshot = Map<int, int>.from(_quantities);
        final pricesSnapshot = Map<int, double>.from(_overriddenPrices);
        final namesSnapshot = Map<int, String>.from(_customNames);
        final clientSnapshot = _selectedClient;
        final cName = _clientNameCtrl.text;
        final cPhone = _clientPhoneCtrl.text;
        final cDni = _clientDniCtrl.text;
        final cAddr = _clientAddressCtrl.text;
        final cEmail = _clientEmailCtrl.text;
        final cNotes = _clientNotesCtrl.text;
        final qTitle = _quoteTitleCtrl.text;
        final qNotes = _quoteNotesCtrl.text;
        final school = _schoolCtrl.text;
        final grade = _gradeCtrl.text;
        final quotationIdSnapshot = _currentQuotationId;
        Future.microtask(() {
          prov.saveManualDraft(
            items: itemsSnapshot,
            quantities: quantitiesSnapshot,
            prices: pricesSnapshot,
            names: namesSnapshot,
            client: clientSnapshot,
            cName: cName,
            cPhone: cPhone,
            cDni: cDni,
            cAddr: cAddr,
            cEmail: cEmail,
            cNotes: cNotes,
            qTitle: qTitle,
            qNotes: qNotes,
            school: school,
            grade: grade,
            quotationId: quotationIdSnapshot,
          );
        });
      } else if (_items.isEmpty) {
        Future.microtask(() => prov.clearManualDraft());
      }
    }

    _quoteTitleCtrl.dispose();
    _quoteNotesCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientDniCtrl.dispose();
    _clientAddressCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientNotesCtrl.dispose();
    _schoolCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  void updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _expandQuoteSectionForTour() async {
    if (!mounted) return;
    _quoteExpandedBeforeTour ??= _isQuoteDataExpanded;
    if (!_isQuoteDataExpanded) {
      setState(() => _isQuoteDataExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _restoreQuoteSectionAfterTour() async {
    final prev = _quoteExpandedBeforeTour;
    _quoteExpandedBeforeTour = null;
    if (!mounted) return;
    if (prev != null && _isQuoteDataExpanded != prev) {
      setState(() => _isQuoteDataExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  Future<void> _expandClientSectionForTour() async {
    if (!mounted) return;
    _clientExpandedBeforeTour ??= _isClientPanelExpanded;
    if (!_isClientPanelExpanded) {
      setState(() => _isClientPanelExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _restoreClientSectionAfterTour() async {
    final prev = _clientExpandedBeforeTour;
    _clientExpandedBeforeTour = null;
    if (!mounted) return;
    if (prev != null && _isClientPanelExpanded != prev) {
      setState(() => _isClientPanelExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  ScreenTourConfig _buildManualTourConfig() {
    return ManualQuotationTour.buildConfig(
      keys: _tourKeys,
      onExpandIdentification: _expandQuoteSectionForTour,
      onRestoreIdentification: _restoreQuoteSectionAfterTour,
      onExpandClientSchool: _expandClientSectionForTour,
      onRestoreClientSchool: _restoreClientSectionAfterTour,
      onExpandFooter: () async {
        await _footerKey.currentState?.expandForTour();
      },
      onRestoreFooter: () async {
        await _footerKey.currentState?.restoreAfterTour();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final auth = Provider.of<AuthProvider>(context);
    final workbench = Provider.of<WorkbenchProvider>(context);
    final isClient = auth.isCommunityClient;
    final isGuest = !auth.hasActiveContext;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          leadingWidth: 38,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            padding: EdgeInsets.zero,
            tooltip: 'Volver',
            onPressed: () => Navigator.maybePop(context),
          ),
          titleSpacing: 0,
          actionsPadding: EdgeInsets.zero,
          title: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isClient
                    ? "Mi Pedido"
                    : (_currentQuotationId == null
                        ? "Nueva Cotización"
                        : "Editar Cotización"),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
          foregroundColor: textColor,
          elevation: 0,
          actions: [
            InfoTooltipButton(
              iconSize: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              title: "Cotización Manual",
              description:
                  "Crea o edita presupuestos personalizados seleccionando productos del catálogo o agregando ítems con precios a medida.",
              tips: const [
                InfoTip(
                  icon: Icons.description_outlined,
                  text:
                      "Abre Identificación de Cotización y Cliente y Colegio para personalizar título, notas o vincular al comprador.",
                ),
                InfoTip(
                  icon: Icons.search_rounded,
                  text:
                      "Toca Buscar Productos para consultar tu inventario con stock en vivo y añadir presentaciones.",
                ),
                InfoTip(
                  icon: Icons.visibility_outlined,
                  text:
                      "Usa el botón de privacidad (ojo) para ocultar costos y ganancias cuando atiendas frente al cliente.",
                ),
                InfoTip(
                  icon: Icons.point_of_sale_rounded,
                  text:
                      "Desliza la barra inferior TOTAL para convertir la cotización en una venta directa con un toque.",
                ),
              ],
              onStartInteractiveTour: () => InteractiveTourService.startManualTour(
                context,
                _buildManualTourConfig(),
              ),
            ),
            Consumer<QuickSaleProvider>(
              builder: (ctx, quickProv, _) => KeyedSubtree(
                key: _tourKeys.privacyEyeKey,
                child: IconButton(
                  icon: Icon(
                    quickProv.hideProfits
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  splashRadius: 18,
                  tooltip: quickProv.hideProfits
                      ? "Modo Cliente (Privacidad activa)"
                      : "Modo Vendedor",
                  onPressed: () => quickProv.toggleHideProfits(),
                ),
              ),
            ),
            if (_items.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.delete_sweep,
                  color: isDark ? Colors.red[400] : Colors.red,
                  size: 21,
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                splashRadius: 18,
                tooltip: "Limpiar Todo",
                onPressed: _clearWholeList,
              ),
            if (!isClient)
              KeyedSubtree(
                key: _tourKeys.saveButtonKey,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, left: 2, top: 8, bottom: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 92),
                    child: FilledButton(
                      onPressed: _isSaving ? null : _openSaveModal,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isSaving
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 17),
                            const SizedBox(width: 5),
                            const Text(
                              "Guardar",
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
        
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (isGuest)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Estás explorando. Agrega productos al carrito para ver cómo funciona, pero no podrás guardar.",
                            style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                          )
                        )
                      ]
                    )
                  ),
                  
                if (_outdatedItemsCount > 0 && !isClient)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15)),
                    child: Row(
                      children: [
                        Icon(Icons.sync_problem, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "$_outdatedItemsCount productos tienen nombres o precios desactualizados en el inventario.",
                            style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[900], fontSize: 13, fontWeight: FontWeight.bold),
                          )
                        ),
                        TextButton(
                           onPressed: () {
                              Provider.of<WorkbenchProvider>(context, listen: false).refreshQuotation(widget.quotationId!, fixPrices: true, fixStock: true, fixNames: true, fixBundles: true).then((_) {
                                 if (!context.mounted) return;
                                 CustomSnackBar.show(context, message: "Cotización actualizada correctamente.", isError: false);
                                 _initData();
                              }).catchError((e) {
                                 if (!context.mounted) return;
                                 CustomSnackBar.show(context, message: "Error al actualizar.", isError: true);
                              });
                           },
                           child: Text("Sincronizar", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold))
                        )
                      ]
                    )
                  ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handlePullToRefresh,
                    child: _items.isEmpty
                      ? CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                          if (!isClient)
                            SliverToBoxAdapter(
                              child: ManualQuoteHeadersSection(
                                identificationKey: _tourKeys.identificationKey,
                                clientSchoolKey: _tourKeys.clientSchoolKey,
                                isDark: isDark, surfaceColor: surfaceColor, textColor: textColor, isGuest: isGuest,
                                isQuoteDataExpanded: _isQuoteDataExpanded, isClientPanelExpanded: _isClientPanelExpanded,
                                onQuoteDataExpansionChanged: (val) => setState(() => _isQuoteDataExpanded = val),
                                onClientPanelExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
                                quoteTitleCtrl: _quoteTitleCtrl, quoteNotesCtrl: _quoteNotesCtrl, schoolCtrl: _schoolCtrl, gradeCtrl: _gradeCtrl,
                                selectedClient: _selectedClient, clientNameCtrl: _clientNameCtrl, clientPhoneCtrl: _clientPhoneCtrl, clientDniCtrl: _clientDniCtrl,
                                clientAddressCtrl: _clientAddressCtrl, clientEmailCtrl: _clientEmailCtrl, clientNotesCtrl: _clientNotesCtrl,
                                isNewClientMode: _updateClientData, onNewClientModeChanged: (v) { setState(() { _updateClientData = v ?? false; _hasUnsavedChanges = true; }); },
                                isAutoTitleMode: _isAutoTitleMode,
                                onRestoreAutoTitle: _restoreAutoTitle,
                                
                                onSearchClientTap: (isGuest || _isAppOrder) ? () {
                                   if (_isAppOrder) {
                                      CustomSnackBar.show(context, message: "Este pedido pertenece a un cliente de la App. Clónalo si deseas asignarlo a otra persona.", isError: true);
                                   } else {
                                      _showExplorationModal(context, isDark);
                                   }
                                } : _showClientSearch, 
                                
                                onClearClient: _isAppOrder ? () {
                                   CustomSnackBar.show(context, message: "No puedes desvincular a un usuario de la App.", isError: true);
                                } : _clearClient,
                              ),
                            ),
                          if (!isClient)
                            SliverToBoxAdapter(
                              child: _buildOffersPanel(isDark),
                            ),
                          SliverFillRemaining(
                            hasScrollBody: false, 
                            child: ManualQuoteEmptyState(
                              isDark: isDark,
                              addButtonKey: _tourKeys.addProductsKey,
                              onAddPressed: () => _showCatalogModal(isDark),
                            ),
                          ),
                        ],
                      )
                    : ReorderableListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        header: Column(
                          children: [
                            ManualQuoteHeadersSection(
                              identificationKey: _tourKeys.identificationKey,
                              clientSchoolKey: _tourKeys.clientSchoolKey,
                              isDark: isDark, surfaceColor: surfaceColor, textColor: textColor, isGuest: isGuest,
                              isQuoteDataExpanded: _isQuoteDataExpanded, isClientPanelExpanded: _isClientPanelExpanded,
                              onQuoteDataExpansionChanged: (val) => setState(() => _isQuoteDataExpanded = val),
                              onClientPanelExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
                              quoteTitleCtrl: _quoteTitleCtrl, quoteNotesCtrl: _quoteNotesCtrl, schoolCtrl: _schoolCtrl, gradeCtrl: _gradeCtrl,
                              selectedClient: _selectedClient, clientNameCtrl: _clientNameCtrl, clientPhoneCtrl: _clientPhoneCtrl, clientDniCtrl: _clientDniCtrl,
                              clientAddressCtrl: _clientAddressCtrl, clientEmailCtrl: _clientEmailCtrl, clientNotesCtrl: _clientNotesCtrl,
                              isNewClientMode: _updateClientData, onNewClientModeChanged: (v) { setState(() { _updateClientData = v ?? false; _hasUnsavedChanges = true; }); },
                              isAutoTitleMode: _isAutoTitleMode,
                              onRestoreAutoTitle: _restoreAutoTitle,
                              
                              onSearchClientTap: (isGuest || _isAppOrder) ? () {
                                 if (_isAppOrder) {
                                    CustomSnackBar.show(context, message: "Este pedido pertenece a un cliente de la App. Clónalo si deseas asignarlo a otra persona.", isError: true);
                                 } else {
                                    _showExplorationModal(context, isDark);
                                 }
                              } : _showClientSearch, 
                              
                              onClearClient: _isAppOrder ? () {
                                 CustomSnackBar.show(context, message: "No puedes desvincular a un usuario de la App.", isError: true);
                              } : _clearClient,
                            ),
                            if (!isClient) _buildOffersPanel(isDark),
                            if (_items.isNotEmpty) _buildProductsSectionHeader(isDark),
                          ],
                        ),
                        padding: const EdgeInsets.only(bottom: 120), 
                        itemCount: _items.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) newIndex -= 1;
                            final item = _items.removeAt(oldIndex);
                            _items.insert(newIndex, item);
                            _hasUnsavedChanges = true;
                          });
                        },
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          final sharedDemand = _computeSharedDemand();
                          final isShared = item.usaStockCompartido && item.productId > 0 && item.sharedStockPool > 0;
                          final currentDemand = isShared ? (sharedDemand[item.productId] ?? 0) : 0;
                          final isSharedPoolExceeded = isShared && currentDemand > item.sharedStockPool;

                          return Padding(
                            key: ValueKey("manual_item_${item.presentationId}_$i"),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ManualQuoteItemCard(
                              item: item, 
                              index: i, 
                              isDark: isDark,
                              isClient: isClient,
                              isEditing: _currentQuotationId != null, 
                              isBundleOutdated: _currentQuotationId != null && item.bundleId != null && (workbench.getValidationFor(_currentQuotationId!)?.bundleChanges.any((bc) => bc.bundleId == item.bundleId) ?? false),
                              isSharedPoolExceeded: isSharedPoolExceeded,
                              sharedPoolDemand: isShared ? currentDemand : null,
                              sharedPoolCapacity: isShared ? item.sharedStockPool : null,
                              quantity: _quantities[item.presentationId] ?? 1,
                              manualPrice: _overriddenPrices[item.presentationId] ?? (item.offerPrice ?? item.price),
                              customName: _customNames[item.presentationId] ?? "", 
                              onTap: () => _editItem(item, i),
                              onDelete: () => setState(() {
                                _items.removeAt(i); _quantities.remove(item.presentationId); _overriddenPrices.remove(item.presentationId); _customNames.remove(item.presentationId); _hasUnsavedChanges = true;
                              }),
                              onIncrease: () {
                                int current = _quantities[item.presentationId] ?? 1;
                                if (isClient && current >= item.effectiveVendibleStock) {
                                  CustomSnackBar.show(context, message: "Límite de stock alcanzado (${item.effectiveVendibleStock} disp.)", isError: true);
                                  return;
                                }
                                if (isClient && isShared) {
                                  final factor = item.conversionFactor > 0 ? item.conversionFactor : 1;
                                  if (currentDemand + factor > item.sharedStockPool) {
                                    CustomSnackBar.show(context, message: "Límite de stock alcanzado en pool compartido (${item.sharedStockPool} und. base)", isError: true);
                                    return;
                                  }
                                }
                                setState(() { 
                                  _quantities[item.presentationId] = current + 1; 
                                  _hasUnsavedChanges = true; 
                                });
                              },
                              onDecrease: () => setState(() { if ((_quantities[item.presentationId] ?? 1) > 1) { _quantities[item.presentationId] = (_quantities[item.presentationId] ?? 1) - 1; _hasUnsavedChanges = true; } }),
                            ),
                          );
                        },
                      ),
                  ),
                ),
              ],
            ),
        
        bottomNavigationBar: KeyedSubtree(
          key: _tourKeys.footerKey,
          child: ManualQuoteFooter(
            key: _footerKey,
            itemCount: _items.length,
            totalSavings: _totalSavings,
            totalAmount: _totalAmount,
            estimatedProfit: _estimatedTotalProfit,
            isSaving: _isSaving,
            isDark: isDark,
            onSellPressed: _onSellPressed,
            customLabel: isClient ? "ENVIAR PEDIDO A TIENDA" : "VENDER (CAJA)",
            customColor: isClient ? Colors.green[700] : Colors.blue[800],
            isClient: isClient,
          ),
        ),
        
        floatingActionButton: (_items.isNotEmpty && !_isQuoteDataExpanded && !_isClientPanelExpanded) 
          ? Padding(
              padding: const EdgeInsets.only(bottom: 85), 
              child: FloatingActionButton(
                onPressed: () => _showCatalogModal(isDark), 
                backgroundColor: isDark ? Colors.orange[400] : Colors.orange[800],
                tooltip: "Agregar Producto",
                child: Icon(Icons.add, color: isDark ? Colors.black87 : Colors.white, size: 28),
              ),
            )
          : null,
      ),
    );
  }

  Widget _buildProductsSectionHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Productos en Cotización (${_items.length})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: _tourKeys.addProductsKey,
            child: InkWell(
              onTap: () => _showCatalogModal(isDark),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 15, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                    const SizedBox(width: 5),
                    Text(
                      "Añadir Ítem",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange[300] : Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}