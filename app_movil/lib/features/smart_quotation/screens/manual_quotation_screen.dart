import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers y Servicios
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
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

  const ManualQuotationScreen({
    super.key, 
    this.quotationId,
    this.quotationSnapshot,
    this.initialItems,
    this.initialQuantities,
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
  bool _hasUnsavedChanges = false;
  bool _isOffersExpanded = false;

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
  bool _isAppOrder = false;

  @override
  void initState() {
    super.initState();
    _currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    _currentQuotationId = widget.quotationId;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isCommunityClient) {
        _clientNameCtrl.text = auth.user?.fullName ?? "";
        _clientEmailCtrl.text = auth.user?.email ?? "";
        
        if (_quoteTitleCtrl.text.isEmpty && _currentQuotationId == null) {
            final String name = (auth.user?.fullName != null && auth.user!.fullName.isNotEmpty) ? auth.user!.fullName : "Cliente";
            _quoteTitleCtrl.text = "$name - Pedido Manual #${DateFormat('dd-HHmm').format(DateTime.now())}";
        }
      }
    });
    
    _clientNameCtrl.addListener(() {
      _markChanged();
      if (_currentQuotationId == null || _quoteTitleCtrl.text.startsWith("Cotización") || _quoteTitleCtrl.text.contains("- Pedido")) {
         _generateDynamicName();
      }
      if (_selectedClient == null && _clientNameCtrl.text.isNotEmpty) {
         if (!_updateClientData) setState(() => _updateClientData = true);
      }
    });

    _quoteTitleCtrl.addListener(_markChanged);
    _quoteNotesCtrl.addListener(_markChanged);
    _schoolCtrl.addListener(_markChanged);
    _gradeCtrl.addListener(_markChanged);
    
    _initData();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
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
  
  void _generateDynamicName() async {
    if (_isGeneratingName) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    bool shouldGenerate = _quoteTitleCtrl.text.isEmpty || 
                          _quoteTitleCtrl.text.startsWith("Cotización") ||
                          _quoteTitleCtrl.text.contains("- Pedido") ||
                          _quoteTitleCtrl.text == "Cliente General";

    if (shouldGenerate) {
        _isGeneratingName = true;
        final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
        
        final newName = await prov.generateDynamicQuoteName(
            _selectedClient, 
            _clientNameCtrl.text, 
            isClientRole: auth.isCommunityClient,
            clientUserName: auth.user?.fullName,
            type: 'manual' 
        );
        
        if (mounted && _quoteTitleCtrl.text != newName) {
           _quoteTitleCtrl.text = newName;
        }
        _isGeneratingName = false;
    }
  }

  @override
  void dispose() {
    if (mounted) {
       final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
       if (_items.isNotEmpty && !_isSaving) {
          prov.saveManualDraft(
            items: _items,
            quantities: _quantities,
            prices: _overriddenPrices,
            names: _customNames,
            client: _selectedClient,
            cName: _clientNameCtrl.text,
            cPhone: _clientPhoneCtrl.text,
            cDni: _clientDniCtrl.text,
            cAddr: _clientAddressCtrl.text,
            cEmail: _clientEmailCtrl.text,
            cNotes: _clientNotesCtrl.text,
            qTitle: _quoteTitleCtrl.text,
            qNotes: _quoteNotesCtrl.text,
            school: _schoolCtrl.text,
            grade: _gradeCtrl.text,
            quotationId: _currentQuotationId,
          );
       } else if (_items.isEmpty) {
          prov.clearManualDraft();
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
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isClient ? "Mi Pedido" : (_currentQuotationId == null ? "Nueva Cotización" : "Editar Cotización"), 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
          foregroundColor: textColor, elevation: 0,
          actions: [
            if (_items.isNotEmpty)
              IconButton(icon: Icon(Icons.delete_sweep, color: isDark ? Colors.red[400] : Colors.red, size: 28), tooltip: "Limpiar Todo", onPressed: _clearWholeList),
            if (!isClient)
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8, top: 8, bottom: 8),
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _openSaveModal,
                  icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 20),
                  label: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  style: FilledButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                  child: _items.isEmpty
                    ? CustomScrollView(
                        slivers: [
                          if (!isClient)
                            SliverToBoxAdapter(
                              child: ManualQuoteHeadersSection(
                                isDark: isDark, surfaceColor: surfaceColor, textColor: textColor, isGuest: isGuest,
                                isQuoteDataExpanded: _isQuoteDataExpanded, isClientPanelExpanded: _isClientPanelExpanded,
                                onQuoteDataExpansionChanged: (val) => setState(() => _isQuoteDataExpanded = val),
                                onClientPanelExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
                                quoteTitleCtrl: _quoteTitleCtrl, quoteNotesCtrl: _quoteNotesCtrl, schoolCtrl: _schoolCtrl, gradeCtrl: _gradeCtrl,
                                selectedClient: _selectedClient, clientNameCtrl: _clientNameCtrl, clientPhoneCtrl: _clientPhoneCtrl, clientDniCtrl: _clientDniCtrl,
                                clientAddressCtrl: _clientAddressCtrl, clientEmailCtrl: _clientEmailCtrl, clientNotesCtrl: _clientNotesCtrl,
                                isNewClientMode: _updateClientData, onNewClientModeChanged: (v) { setState(() { _updateClientData = v ?? false; _hasUnsavedChanges = true; }); },
                                
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
                            child: ManualQuoteEmptyState(isDark: isDark, onAddPressed: () => _showCatalogModal(isDark)),
                          ),
                        ],
                      )
                    : ReorderableListView.builder(
                        header: Column(
                          children: [
                            ManualQuoteHeadersSection(
                              isDark: isDark, surfaceColor: surfaceColor, textColor: textColor, isGuest: isGuest,
                              isQuoteDataExpanded: _isQuoteDataExpanded, isClientPanelExpanded: _isClientPanelExpanded,
                              onQuoteDataExpansionChanged: (val) => setState(() => _isQuoteDataExpanded = val),
                              onClientPanelExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
                              quoteTitleCtrl: _quoteTitleCtrl, quoteNotesCtrl: _quoteNotesCtrl, schoolCtrl: _schoolCtrl, gradeCtrl: _gradeCtrl,
                              selectedClient: _selectedClient, clientNameCtrl: _clientNameCtrl, clientPhoneCtrl: _clientPhoneCtrl, clientDniCtrl: _clientDniCtrl,
                              clientAddressCtrl: _clientAddressCtrl, clientEmailCtrl: _clientEmailCtrl, clientNotesCtrl: _clientNotesCtrl,
                              isNewClientMode: _updateClientData, onNewClientModeChanged: (v) { setState(() { _updateClientData = v ?? false; _hasUnsavedChanges = true; }); },
                              
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
                              quantity: _quantities[item.presentationId] ?? 1,
                              manualPrice: _overriddenPrices[item.presentationId] ?? (item.offerPrice ?? item.price),
                              customName: _customNames[item.presentationId] ?? "", 
                              onTap: () => _editItem(item, i),
                              onDelete: () => setState(() {
                                _items.removeAt(i); _quantities.remove(item.presentationId); _overriddenPrices.remove(item.presentationId); _customNames.remove(item.presentationId); _hasUnsavedChanges = true;
                              }),
                              onIncrease: () {
                                int current = _quantities[item.presentationId] ?? 1;
                                if (isClient && current >= item.stock) {
                                  CustomSnackBar.show(context, message: "Límite de stock alcanzado (${item.stock} disp.)", isError: true);
                                  return;
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
              ],
            ),
        
        bottomNavigationBar: ManualQuoteFooter(
          itemCount: _items.length, 
          totalSavings: _totalSavings, 
          totalAmount: _totalAmount, 
          isSaving: _isSaving, 
          isDark: isDark, 
          onSellPressed: _onSellPressed,
          customLabel: isClient ? "ENVIAR PEDIDO A TIENDA" : "VENDER (CAJA)",
          customColor: isClient ? Colors.green[700] : Colors.blue[800],
          isClient: isClient
        ),
        
        floatingActionButton: _items.isNotEmpty 
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
}