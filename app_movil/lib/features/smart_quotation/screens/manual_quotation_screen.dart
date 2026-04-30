import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers y Servicios
import '../providers/workbench_provider.dart';
import '../providers/smart_quotation_provider.dart';
import '../../../providers/inventory_provider.dart'; 
import '../../../providers/auth_provider.dart';
import '../services/client_service.dart';

// Modelos
import '../models/smart_quotation_model.dart';
import '../models/matching_model.dart';
import '../models/crm_models.dart';

// Widgets Modulares
import '../../../../widgets/custom_snackbar.dart';
import '../widgets/manual/catalog_search_modal.dart';
import '../widgets/manual/manual_quote_detail_modal.dart';
import '../widgets/manual/manual_quote_item_card.dart';        
import '../widgets/manual/manual_quote_footer.dart';             
import '../widgets/manual/manual_quote_save_modal.dart';         
import '../widgets/manual/manual_quote_empty_state.dart';        
import '../widgets/manual/manual_quote_headers_section.dart'; 
import '../widgets/manual/client_search_modal.dart'; 
import '../widgets/manual/manual_quote_dialog_helper.dart'; 

// Pantallas Destino
import 'sales_checkout_screen.dart';
import 'quotation_detail_screen.dart';
import 'client_orders_screen.dart';

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
  
  bool _isQuoteDataExpanded = false; 
  bool _isClientPanelExpanded = false;
  bool _hasUnsavedChanges = false;
  
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

  Future<void> _initData() async {
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);

    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      setState(() {
        _items = List.from(widget.initialItems!);
        for (var item in _items) {
          int qty = widget.initialQuantities?[item.presentationId] ?? 1;
          _quantities[item.presentationId] = qty; 
        }
        _hasUnsavedChanges = true; 
      });
      _generateDynamicName();
      return;
    }

    if (_currentQuotationId != null) {
      setState(() => _isLoading = true);
      final invProv = Provider.of<InventoryProvider>(context, listen: false); 
      final clientService = ClientService();
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      
      SmartQuotationModel? data = widget.quotationSnapshot ?? await prov.getQuotationById(_currentQuotationId!);

      if (data != null) {
        _quoteTitleCtrl.text = data.clientName ?? "";
        _quoteNotesCtrl.text = data.notas ?? "";
        _schoolCtrl.text = data.institutionName ?? "";
        _gradeCtrl.text = data.gradeLevel ?? "";
        
        _isAppOrder = (data.clientName ?? "").contains("- Pedido");
        
        if (data.clientId != null && !authProv.isCommunityClient) {
          try {
            // 🔥 CORRECCIÓN 1: Se quitó authProv.token!
            final client = await clientService.getClientById(data.clientId!);
            if (client != null) {
              _selectedClient = client;
              _clientNameCtrl.text = client.fullName;
              _clientPhoneCtrl.text = client.phone;
              _clientDniCtrl.text = client.docNumber ?? "";
              _clientAddressCtrl.text = client.address ?? "";
              _clientEmailCtrl.text = client.email ?? "";
              _clientNotesCtrl.text = client.notes ?? "";
            }
          } catch (_) {}
        }

        List<MatchedProduct> convertedItems = [];
        for (var qItem in data.items) {
          int realStock = 0;
          String? realImageUrl = qItem.imageUrl;
          String currentUnit = qItem.salesUnit ?? "Unidad";
          int currentConversion = 1;
          
          try {
            final realProduct = await invProv.fetchProductById(qItem.productId ?? 0);
            if (realProduct != null) {
               final pres = realProduct.presentaciones.firstWhere((p) => p.id == qItem.presentationId);
               realStock = pres.stockActual;
               realImageUrl = pres.imagenUrl ?? realProduct.imagenUrl;
               currentUnit = pres.unidadVenta ?? "Unidad";
               currentConversion = pres.unidadesPorVenta;
            }
          } catch(e) { debugPrint("Producto no encontrado"); }

          final matched = MatchedProduct(
            productId: qItem.productId ?? 0, 
            presentationId: qItem.presentationId ?? 0,
            fullName: qItem.displayName,
            productName: qItem.productName ?? "", 
            specificName: qItem.specificName,
            brand: qItem.brandName,
            price: qItem.originalUnitPrice, 
            stock: realStock, 
            imageUrl: realImageUrl, 
            unit: currentUnit,
            conversionFactor: currentConversion
          );
          
          _quantities[matched.presentationId] = qItem.quantity;
          if ((qItem.unitPriceApplied - qItem.originalUnitPrice).abs() > 0.01) {
             _overriddenPrices[matched.presentationId] = qItem.unitPriceApplied;
          }
          
          if (qItem.productName == null || qItem.productName!.isEmpty) {
              _customNames[matched.presentationId] = qItem.displayName;
          }

          convertedItems.add(matched);
        }

        setState(() { _items = convertedItems; _hasUnsavedChanges = false; });
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (prov.hasManualDraft && _currentQuotationId == null) {
      setState(() {
        _items = List.from(prov.draftManualItems!);
        _quantities.addAll(prov.draftManualQuantities!);
        _overriddenPrices.addAll(prov.draftManualPrices!);
        _customNames.addAll(prov.draftManualNames!);
        if (prov.draftClient != null) _selectClient(prov.draftClient!);
        
        _clientNameCtrl.text = prov.draftClientName ?? ""; _clientPhoneCtrl.text = prov.draftClientPhone ?? "";
        _clientDniCtrl.text = prov.draftClientDni ?? ""; _clientAddressCtrl.text = prov.draftClientAddress ?? "";
        _clientEmailCtrl.text = prov.draftClientEmail ?? ""; _clientNotesCtrl.text = prov.draftClientNotes ?? "";
        
        _quoteTitleCtrl.text = prov.draftQuoteTitle ?? ""; _quoteNotesCtrl.text = prov.draftQuoteNotes ?? "";
        _schoolCtrl.text = prov.draftSchool ?? ""; _gradeCtrl.text = prov.draftGrade ?? "";
        
        _currentQuotationId = prov.draftQuotationId;
        _hasUnsavedChanges = true; 
      });
    } else {
        _generateDynamicName();
    }
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) {
      final price = _overriddenPrices[item.presentationId] ?? (item.offerPrice ?? item.price);
      return sum + (price * (_quantities[item.presentationId] ?? 1)); 
    });
  }

  double get _totalSavings {
    double totalListPrice = _items.fold(0.0, (sum, item) => sum + (item.price * (_quantities[item.presentationId] ?? 1)));
    final savings = totalListPrice - _totalAmount;
    return savings > 0 ? savings : 0.0;
  }

  void _selectClient(ClientModel client) async {
    setState(() {
      _selectedClient = client;
      _updateClientData = true; 
      _clientNameCtrl.text = client.fullName;
      _clientPhoneCtrl.text = client.phone;
      _clientDniCtrl.text = client.docNumber ?? "";
      _clientAddressCtrl.text = client.address ?? "";
      _clientEmailCtrl.text = client.email ?? "";
      _clientNotesCtrl.text = client.notes ?? "";
      _hasUnsavedChanges = true;
    });

    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final newName = await prov.generateDynamicQuoteName(client, client.fullName, isClientRole: auth.isCommunityClient, clientUserName: auth.user?.fullName, type: 'manual');
    if (mounted) _quoteTitleCtrl.text = newName;
  }

  void _clearClient() {
    setState(() {
      _selectedClient = null; _updateClientData = true; 
      _clientNameCtrl.clear(); _clientPhoneCtrl.clear(); _clientDniCtrl.clear();
      _clientAddressCtrl.clear(); _clientEmailCtrl.clear(); _clientNotesCtrl.clear();
      _hasUnsavedChanges = true;
    });
    _generateDynamicName();
  }

  void _showClientSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientSearchModal(
        onClientSelected: (client) => _selectClient(client),
      ),
    );
  }

  void _clearWholeList() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool? confirm = await ManualQuoteDialogHelper.showClearWholeListDialog(context, isDark);
    
    if (confirm == true) {
      setState(() {
        _items.clear(); _quantities.clear(); _overriddenPrices.clear(); _customNames.clear();
        _clearClient(); _quoteTitleCtrl.clear(); _quoteNotesCtrl.clear(); _schoolCtrl.clear(); _gradeCtrl.clear();
        _hasUnsavedChanges = true;
      });
      Provider.of<SmartQuotationProvider>(context, listen: false).clearManualDraft();
      _generateDynamicName();
    }
  }

  Future<bool> _onWillPop() async {
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_currentQuotationId == null) {
      if (_items.isNotEmpty || _clientNameCtrl.text.isNotEmpty || _quoteTitleCtrl.text.isNotEmpty) {
        prov.saveManualDraft(
          items: _items, quantities: _quantities, prices: _overriddenPrices, names: _customNames,
          client: _selectedClient, cName: _clientNameCtrl.text, cPhone: _clientPhoneCtrl.text, cDni: _clientDniCtrl.text, 
          cAddr: _clientAddressCtrl.text, cEmail: _clientEmailCtrl.text, cNotes: _clientNotesCtrl.text, school: _schoolCtrl.text, 
          grade: _gradeCtrl.text, qTitle: _quoteTitleCtrl.text, qNotes: _quoteNotesCtrl.text, quotationId: _currentQuotationId,
        );
      }
      return true; 
    }

    if (_currentQuotationId != null && _hasUnsavedChanges && !auth.isCommunityClient) {
      bool? shouldPop = await ManualQuoteDialogHelper.showUnsavedChangesDialog(context, isDark);
      if (shouldPop == true) prov.clearManualDraft(); 
      return shouldPop ?? false;
    }

    return true;
  }

  void _onSellPressed() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    if (_items.isEmpty) {
      CustomSnackBar.show(context, message: "Agrega al menos un producto", isError: true);
      return;
    }

    if (auth.isCommunityClient) {
       _showClientOrderConfirmation(isDark);
       return;
    }

    bool hasStockIssues = _items.any((item) => (_quantities[item.presentationId] ?? 1) > item.stock || item.stock <= 0);

    if (hasStockIssues) {
      bool? proceed = await ManualQuoteDialogHelper.showStockIssuesDialog(context, isDark);
      if (proceed == true) _executeSave(status: 'PENDING', type: 'manual', navigateToDetail: true); 
    } else {
      bool? proceed = await ManualQuoteDialogHelper.showConfirmSaleDialog(context, isDark);
      if (proceed == true) _executeSave(status: 'PENDING', type: 'manual', navigateToCheckout: true);
    }
  }

  void _showClientOrderConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Enviar Pedido a Tienda", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(
          "Tu pedido será enviado al negocio para verificar la disponibilidad de los productos.\n\n"
          "Podrás ver el estado de tu pedido en la sección 'Mis Pedidos'. ¿Deseas enviarlo ahora?",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSave(status: 'PENDING_APPROVAL', type: 'manual', navigateToDetail: true, isClientEnd: true);
            },
            child: const Text("Sí, Enviar Pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Future<void> _executeSave({required String status, required String type, bool navigateToDetail = false, bool navigateToCheckout = false, bool isClientEnd = false, bool forceClone = false}) async {
    setState(() => _isSaving = true);
    
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();
    int? finalClientId = _selectedClient?.id;

    if (!authProv.isCommunityClient && _updateClientData && _clientNameCtrl.text.isNotEmpty) {
      final clientData = {
        'nombre_completo': _clientNameCtrl.text, 'telefono': _clientPhoneCtrl.text.replaceAll(" ", ""),
        'dni_ruc': _clientDniCtrl.text, 'direccion': _clientAddressCtrl.text,
        'correo': _clientEmailCtrl.text, 'notas': _clientNotesCtrl.text
      };
      try {
        if (_selectedClient != null) {
          // 🔥 CORRECCIÓN 2: Se quitó authProv.token!
          await clientService.updateClient(_selectedClient!.id, clientData);
        } else {
          // 🔥 CORRECCIÓN 3: Se quitó authProv.token! y se inyectaron los IDs activos
          final newClient = await clientService.createClient(clientData, authProv.activeBusinessId!, authProv.activeUserId!);
          finalClientId = newClient.id;
        }
      } catch (e) { debugPrint("Error saving client: $e"); }
    }

    final itemsPayload = _items.map((item) {
      final qty = _quantities[item.presentationId] ?? 1;
      final manualPrice = _overriddenPrices[item.presentationId];
      
      return {
        "product_id": item.productId, 
        "presentation_id": item.presentationId, 
        "quantity": qty,
        "unit_price_applied": manualPrice ?? (item.offerPrice ?? item.price), 
        "original_unit_price": item.price, 
        "product_name": item.productName,
        "brand_name": item.brand,
        "specific_name": item.specificName,
        "sales_unit": item.unit,
        "is_manual_price": manualPrice != null, 
        "image_url": item.imageUrl 
      };
    }).toList();

    final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
    final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
    
    String finalQuoteName = _quoteTitleCtrl.text.trim();

    if (finalQuoteName.isEmpty || finalQuoteName == "Cliente General") {
        final uniqueCode = DateFormat('dd-HHmm').format(DateTime.now());
        if (authProv.isCommunityClient) {
            final String name = (authProv.user?.fullName != null && authProv.user!.fullName.isNotEmpty) ? authProv.user!.fullName : "Cliente";
            finalQuoteName = "$name - Pedido Manual #$uniqueCode";
        } else if (type == 'pack') {
            finalQuoteName = _clientNameCtrl.text.isNotEmpty ? "Pack Escolar de ${_clientNameCtrl.text} #$uniqueCode" : "Pack Escolar #$uniqueCode";
        } else {
            finalQuoteName = _clientNameCtrl.text.isNotEmpty ? "${_clientNameCtrl.text} #$uniqueCode" : "Cotización Manual #$uniqueCode";
        }
    }

    int? targetQuotationId = forceClone ? null : _currentQuotationId;

    final newId = await wbProv.saveManualQuotation(
      id: targetQuotationId, clientId: finalClientId, clientName: finalQuoteName, notas: _quoteNotesCtrl.text,
      institution: _schoolCtrl.text, grade: _gradeCtrl.text, totalAmount: _totalAmount, totalSavings: _totalSavings,
      items: itemsPayload, status: status, type: type 
    );

    if (mounted) {
      setState(() { _isSaving = false; _hasUnsavedChanges = false; });

      if (newId != null) {
        _currentQuotationId = newId;
        qProv.clearManualDraft(); 

        if (isClientEnd) {
           CustomSnackBar.show(context, message: "¡Tu pedido fue enviado a la tienda!", isError: false);
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
           return;
        }

        if (navigateToCheckout) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: newId)));
        } else if (navigateToDetail) {
          if (widget.quotationId != null && widget.quotationId == newId) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newId)));
          }
        } else {
          CustomSnackBar.show(context, message: forceClone ? "Pedido clonado exitosamente" : "Guardado exitosamente", isError: false);
        }
      } else {
        CustomSnackBar.show(context, message: "Error al guardar localmente", isError: true);
      }
    }
  }

  void _openSaveModal() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    if (_items.isEmpty) {
      CustomSnackBar.show(context, message: "La lista está vacía", isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => ManualQuoteSaveModal(
        isEditing: _currentQuotationId != null,
        isAppOrder: _isAppOrder,
        onSave: (status, type, {bool forceClone = false}) {
          String finalStatus = status == 'MAINTAIN_CURRENT' ? (widget.quotationSnapshot?.status ?? 'DRAFT') : status;
          _executeSave(status: finalStatus, type: type, navigateToDetail: true, forceClone: forceClone);
        },
      ),
    );
  }

  void _showCatalogModal(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: false,
      builder: (ctx) => CatalogSearchModal(
        onAddProduct: (product, quantity, overridePrice, customName) {
          setState(() {
            final index = _items.indexWhere((p) => p.presentationId == product.presentationId);
            if (index != -1) {
              _quantities[product.presentationId] = (_quantities[product.presentationId] ?? 0) + quantity;
            } else { 
              _items.add(product); _quantities[product.presentationId] = quantity; 
            }
            if (overridePrice != null) _overriddenPrices[product.presentationId] = overridePrice;
            if (customName != null) _customNames[product.presentationId] = customName;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  void _editItem(MatchedProduct item, int index) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: false, 
      builder: (ctx) => ManualQuoteDetailModal(
        product: item, initialQty: _quantities[item.presentationId] ?? 1,
        initialOverridePrice: _overriddenPrices[item.presentationId], initialCustomName: _customNames[item.presentationId],
        isNewAddition: false,
        onConfirm: (newProd, newQty, newPrice, newName) {
          setState(() {
            if (newProd.presentationId != item.presentationId) {
              _items.removeAt(index); _quantities.remove(item.presentationId); _overriddenPrices.remove(item.presentationId); _customNames.remove(item.presentationId);
              _items.insert(index, newProd); _quantities[newProd.presentationId] = newQty;
              if (!auth.isCommunityClient && newPrice != null) _overriddenPrices[newProd.presentationId] = newPrice;
              if (newName != null) _customNames[newProd.presentationId] = newName;
            } else {
              _quantities[item.presentationId] = newQty;
              if (!auth.isCommunityClient && newPrice != null) {
                _overriddenPrices[item.presentationId] = newPrice;
              } else {
                _overriddenPrices.remove(item.presentationId);
              }
              if (newName != null) _customNames[item.presentationId] = newName;
            }
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final auth = Provider.of<AuthProvider>(context);
    final isClient = auth.isCommunityClient;
    final isGuest = !auth.hasActiveContext;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            isClient ? "Mi Pedido" : (_currentQuotationId == null ? "Nueva Cotización" : "Editar Cotización"), 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)
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
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15)),
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
                          SliverFillRemaining(
                            hasScrollBody: false, 
                            child: ManualQuoteEmptyState(isDark: isDark, onAddPressed: () => _showCatalogModal(isDark)),
                          ),
                        ],
                      )
                    : ReorderableListView.builder(
                        header: isClient ? const SizedBox(height: 10) : ManualQuoteHeadersSection(
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