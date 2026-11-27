import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
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
part 'manual_quotation/manual_quotation_actions_and_tours_part.dart';
part 'manual_quotation/manual_quotation_appbar_and_headers_part.dart';
part 'manual_quotation/manual_quotation_body_and_items_part.dart';

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

  SmartQuotationProvider? _smartQuotationProv;

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
          final String name =
              (auth.user?.fullName != null && auth.user!.fullName.isNotEmpty)
              ? auth.user!.fullName
              : "Cliente";
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
        if (!_updateClientData) {
          setState(() => _updateClientData = true);
        }
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
    if (mounted) {
      setState(fn);
    }
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
        if (didPop) {
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: _buildAppBar(
          context: context,
          isDark: isDark,
          textColor: textColor,
          isClient: isClient,
        ),
        body: _buildBody(
          context: context,
          isDark: isDark,
          surfaceColor: surfaceColor,
          textColor: textColor,
          isClient: isClient,
          isGuest: isGuest,
          workbench: workbench,
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
        floatingActionButton:
            (_items.isNotEmpty &&
                !_isQuoteDataExpanded &&
                !_isClientPanelExpanded)
            ? Padding(
                padding: const EdgeInsets.only(bottom: 85),
                child: FloatingActionButton(
                  onPressed: () => _showCatalogModal(isDark),
                  backgroundColor: isDark
                      ? Colors.orange[400]
                      : Colors.orange[800],
                  tooltip: "Agregar Producto",
                  child: Icon(
                    Icons.add,
                    color: isDark ? Colors.black87 : Colors.white,
                    size: 28,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
