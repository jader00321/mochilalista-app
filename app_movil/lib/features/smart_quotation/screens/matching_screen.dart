import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/inventory_provider.dart';
import '../../../models/inventory_wrapper.dart';
import '../../../models/product_model.dart';
import '../models/crm_models.dart'; 
import '../../../widgets/custom_snackbar.dart';

import '../models/extracted_list_model.dart';
import '../models/matching_model.dart';
import '../providers/matching_provider.dart';
import '../providers/smart_quotation_provider.dart'; 

import '../widgets/matching/product_quote_detail_modal.dart';
import '../widgets/matching/matching_item_row.dart'; 
import '../widgets/matching/matching_product_search_modal.dart'; 
import '../widgets/matching/matching_smart_bottom_bar.dart'; 

import '../widgets/manual/manual_quote_client_header.dart'; 
import '../widgets/manual/manual_quote_institution_header.dart'; 
import '../services/client_service.dart';
import '../../../providers/auth_provider.dart';

import 'workbench_screen.dart';
import 'pdf_preview_screen.dart';   
import 'whatsapp_preview_screen.dart'; 
import 'quotation_detail_screen.dart';
import 'client_orders_screen.dart'; 
import '../../../screens/home_screen.dart'; 

class MatchingScreen extends StatefulWidget {
  final List<ExtractedItem> extractedItems;
  final ExtractedMetadata? metadata;
  // 🔥 ELIMINADO: final String token; (Ya no se necesita en modo offline/multi-perfil)

  const MatchingScreen({
    super.key,
    required this.extractedItems,
    this.metadata,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _schoolCtrl;
  late TextEditingController _gradeCtrl;
  
  var _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientDniCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientNotesCtrl = TextEditingController();
  
  bool _updateClientData = true; 
  bool _isClientPanelExpanded = false; 

  bool _isFabOpen = false;
  late AnimationController _fabAnimationCtrl;
  late Animation<double> _fabRotateAnim;

  @override
  void initState() {
    super.initState();
    
    final provider = Provider.of<MatchingProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;
    
    String initSchool = widget.metadata?.institutionName ?? "";
    String initClient = widget.metadata?.studentName ?? "";
    String initGrade = widget.metadata?.gradeLevel ?? "";

    // 🔥 VINCULACIÓN VISUAL DEL CLIENTE VIP
    if (isClient) {
       initClient = auth.user?.fullName ?? initClient;
       _clientPhoneCtrl.text = auth.user?.phone ?? "";
       _clientEmailCtrl.text = auth.user?.email ?? "";
       
       // Simulamos un ClientModel propio para que la UI muestre "Cliente Vinculado"
       final mySelf = ClientModel(
         id: 0, 
         negocioId: 0, creadoPorUsuarioId: 0,
         usuarioVinculadoId: auth.user?.id,
         fullName: auth.user?.fullName ?? "Mi Cuenta",
         phone: auth.user?.phone ?? "",
         registeredDate: DateTime.now().toIso8601String()
       );
       provider.setClient(mySelf);
    }

    if (provider.pairs.isNotEmpty) {
      initSchool = provider.metadata?.institutionName ?? initSchool;
      initClient = provider.selectedClient?.fullName ?? provider.metadata?.studentName ?? initClient;
      initGrade = provider.metadata?.gradeLevel ?? initGrade;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 🔥 CORRECCIÓN 1: Se quitó widget.token
        provider.initializeAndMatch(
            widget.extractedItems, 
            widget.metadata, 
            isClientRole: isClient
        );
      });
    }

    _schoolCtrl = TextEditingController(text: initSchool);
    _gradeCtrl = TextEditingController(text: initGrade);
    _clientNameCtrl = TextEditingController(text: initClient);

    _fabAnimationCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fabRotateAnim = Tween<double>(begin: 0.0, end: 0.5).animate(_fabAnimationCtrl);
  }

  @override
  void dispose() {
    _schoolCtrl.dispose(); _gradeCtrl.dispose();
    _clientNameCtrl.dispose(); _clientPhoneCtrl.dispose(); _clientDniCtrl.dispose();
    _clientAddressCtrl.dispose(); _clientEmailCtrl.dispose(); _clientNotesCtrl.dispose();
    _fabAnimationCtrl.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationCtrl.forward();
      } else {
        _fabAnimationCtrl.reverse();
      }
    });
  }

  void _updateHeader() {
    Provider.of<MatchingProvider>(context, listen: false).updateMetadata(
      institution: _schoolCtrl.text, student: _clientNameCtrl.text, grade: _gradeCtrl.text,
    );
  }

  void _selectClient(ClientModel client) {
    setState(() {
      _updateClientData = true;
      _clientNameCtrl.text = client.fullName;
      _clientPhoneCtrl.text = client.phone;
      _clientDniCtrl.text = client.docNumber ?? "";
      _clientAddressCtrl.text = client.address ?? "";
      _clientEmailCtrl.text = client.email ?? "";
      _clientNotesCtrl.text = client.notes ?? "";
    });
    Provider.of<MatchingProvider>(context, listen: false).setClient(client);
  }

  void _clearClient() {
    setState(() {
      _updateClientData = true;
      _clientNameCtrl.clear();
      _clientPhoneCtrl.clear();
      _clientDniCtrl.clear();
      _clientAddressCtrl.clear();
      _clientEmailCtrl.clear();
      _clientNotesCtrl.clear();
    });
    Provider.of<MatchingProvider>(context, listen: false).setClient(null);
  }

  void _showClientSearch(bool isDark) async {
    final clientService = ClientService();
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final textColor = isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Future<List<ClientModel>>? searchFuture;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                            const SizedBox(height: 20),
                            Text("Buscar Cliente", style: textTheme.displayMedium?.copyWith(color: textColor)),
                            const SizedBox(height: 16),
                            TextField(
                              autofocus: true,
                              style: textTheme.bodyLarge?.copyWith(color: textColor),
                              decoration: InputDecoration(
                                hintText: "Ej: Juan Perez...",
                                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                                prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), 
                                filled: true, 
                                fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100]
                              ),
                              onChanged: (val) {
                                if (val.isNotEmpty) {
                                  setModalState(() {
                                    // 🔥 CORRECCIÓN 2: Se usa activeBusinessId en lugar de token!
                                    if (authProv.activeBusinessId != null) {
                                      searchFuture = clientService.searchClients(val, authProv.activeBusinessId!).then(
                                        (clients) => clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList()
                                      );
                                    }
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: searchFuture == null
                          ? Center(child: Text("Escribe para buscar", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey)))
                          : FutureBuilder<List<ClientModel>>(
                              future: searchFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.red[300] : Colors.red)));
                                if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("No se encontraron coincidencias", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)));
                                
                                return ListView.separated(
                                  controller: scrollController, 
                                  itemCount: snapshot.data!.length, 
                                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                  itemBuilder: (context, index) {
                                    final c = snapshot.data![index];
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                      leading: CircleAvatar(backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18))),
                                      title: Text(c.fullName, style: textTheme.titleMedium?.copyWith(color: textColor)),
                                      subtitle: Text(c.phone, style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                      onTap: () { _selectClient(c); Navigator.pop(ctx); },
                                    );
                                  },
                                );
                              },
                            ),
                      )
                    ],
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  Future<bool> _onWillPop(bool isDark) async {
    final provider = Provider.of<MatchingProvider>(context, listen: false);
    if (provider.pairs.isEmpty) {
      provider.clearState();
      return true;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Pausar Pedido?", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text("Tu progreso no se perderá. Podrás continuar editando esta lista cuando vuelvas a abrir el escáner.\n\n¿Deseas salir al menú principal?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Quedarme", style: TextStyle(color: Colors.grey, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Pausar y Salir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          ),
        ],
      )
    );
    return confirm ?? false;
  }

  Future<void> _handleActionWithConfirmation(String actionType, bool isDark) async {
    final provider = Provider.of<MatchingProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isClient = authProv.isCommunityClient;

    if (isClient) {
      bool hasInvalidStock = false;
      for (var pair in provider.pairs) {
        if (pair.selectedProduct != null) {
          if (pair.selectedProduct!.stock <= 0 || pair.selectedQuantity > pair.selectedProduct!.stock) {
            hasInvalidStock = true; 
            break;
          }
        }
      }
      
      if (hasInvalidStock) {
        CustomSnackBar.show(context, message: "Tienes productos agotados o que superan el stock disponible. Ajusta las cantidades para enviar el pedido.", isError: true);
        return; 
      }
    }

    bool hasWarnings = provider.hasStockWarnings;

    String title = "Guardar Cotización";
    String content = "Se generará la lista final en estado 'Pendiente' en tu Mesa de Trabajo.";
    String btnText = "Confirmar";

    if (actionType == 'client_send') {
       title = "Enviar Pedido a Tienda";
       content = "Tu pedido será enviado al negocio para verificar la disponibilidad. Podrás ver el estado en 'Mis Pedidos'.";
       btnText = "Enviar Pedido";
    } else if (hasWarnings && (actionType == 'pdf' || actionType == 'whatsapp')) {
      title = "⚠️ Problemas de Stock";
      content = "Tu lista contiene productos agotados o que superan el stock disponible.\n\n¿Estás seguro de que deseas guardar y generar el documento para el cliente?";
      btnText = "Generar Igual";
    }

    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: hasWarnings ? (isDark ? Colors.red[400] : Colors.red[800]) : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hasWarnings ? (isDark ? Colors.red[800] : Colors.red) : (isClient ? Colors.green[700] : Colors.blue[800]), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          ),
        ],
      )
    );

    if (confirm != true) return;
    if (_isFabOpen) _toggleFab();

    // 🔥 CORRECCIÓN 3: Se quitó widget.token de esta función
    int? newId = await provider.saveQuotation(
      isClient ? 'PENDING_APPROVAL' : 'PENDING', 
      manualClientName: _clientNameCtrl.text,
      manualClientPhone: _clientPhoneCtrl.text,
      manualClientDni: _clientDniCtrl.text,
      manualClientAddress: _clientAddressCtrl.text,
      manualClientEmail: _clientEmailCtrl.text,
      manualClientNotes: _clientNotesCtrl.text,
      updateClientData: _updateClientData, 
      institutionName: _schoolCtrl.text, 
      gradeLevel: _gradeCtrl.text, 
      type: 'ai_scan', 
      isClientRole: isClient 
    );

    if (newId != null && mounted) {
      provider.clearState(); 
      Provider.of<SmartQuotationProvider>(context, listen: false).clearState();
      
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);

      if (actionType == 'client_send') {
         CustomSnackBar.show(context, message: "¡Tu pedido fue enviado a la tienda!", isError: false);
         Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
      } else if (actionType == 'save') {
         Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkbenchScreen()));
      } else {
         Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newId)));
         if (actionType == 'pdf') {
           Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(quotationId: newId)));
         } else if (actionType == 'whatsapp') {
           Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsAppPreviewScreen(quotationId: newId)));
         }
      }
    } else if (mounted) {
      CustomSnackBar.show(context, message: "Error: ${provider.errorMessage}", isError: true);
    }
  }

  void _resetToInitial(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.settings_backup_restore, color: isDark ? Colors.orange[300] : Colors.orange, size: 28), const SizedBox(width: 10), Text("Reiniciar Análisis", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
        content: Text("¿Estás seguro de volver al estado original escaneado por la IA? Perderás tus modificaciones manuales y el cliente seleccionado.", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.orange[800] : Colors.orange[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              final provider = Provider.of<MatchingProvider>(context, listen: false);
              
              provider.resetToInitialState();
              
              setState(() {
                _updateClientData = true; 
                _schoolCtrl.text = provider.metadata?.institutionName ?? "";
                _gradeCtrl.text = provider.metadata?.gradeLevel ?? "";
                _clientNameCtrl.text = provider.metadata?.studentName ?? "";
                
                _clientPhoneCtrl.clear();
                _clientDniCtrl.clear();
                _clientAddressCtrl.clear();
                _clientEmailCtrl.clear();
                _clientNotesCtrl.clear();
              });
            }, 
            child: const Text("Sí, reiniciar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          )
        ]
      )
    );
  }

  void _openDetailsModal(BuildContext context, MatchPair pair) {
    if (pair.selectedProduct == null) return;
    final inventoryProv = Provider.of<InventoryProvider>(context, listen: false);
    Product? fullProduct;
    
    try {
      fullProduct = inventoryProv.products.firstWhere((p) => p.id == pair.selectedProduct!.productId);
    } catch (_) {
      fullProduct = Product(
        id: pair.selectedProduct!.productId, nombre: pair.selectedProduct!.productName, categoriaId: 0, imagenUrl: pair.selectedProduct!.imageUrl, marcaId: null, 
        presentaciones: [
          ProductPresentation(
            id: pair.selectedProduct!.presentationId, 
            umpCompra: pair.selectedProduct!.unit, 
            nombreEspecifico: pair.selectedProduct!.specificName, 
            precioVentaFinal: pair.selectedProduct!.price, 
            stockActual: pair.selectedProduct!.stock, 
            unidadesPorLote: pair.selectedProduct!.conversionFactor, 
            imagenUrl: pair.selectedProduct!.imageUrl,
          )
        ]
      );
    }

    final currentPres = fullProduct.presentaciones.firstWhere((p) => p.id == pair.selectedProduct!.presentationId, orElse: () => fullProduct!.presentaciones.first);
    final wrapper = InventoryWrapper(product: fullProduct, presentation: currentPres);
    String? brandName = fullProduct.marcaId != null ? inventoryProv.getBrandName(fullProduct.marcaId) : pair.selectedProduct!.brand; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) => ProductQuoteDetailModal(
        wrapper: wrapper,
        brandName: brandName,
        currentQuantity: pair.selectedQuantity,
        currentOverridePrice: pair.overridePrice,
        onSave: (newPres, newQty, newPrice, _) { 
          final provider = Provider.of<MatchingProvider>(context, listen: false);
          
          final newMatched = MatchedProduct(
            productId: fullProduct!.id, 
            presentationId: newPres.id!, 
            fullName: fullProduct.nombre, 
            productName: fullProduct.nombre, 
            specificName: newPres.nombreEspecifico, 
            brand: brandName, 
            price: newPres.precioVentaFinal, 
            offerPrice: newPres.precioOferta, 
            stock: newPres.stockActual, 
            imageUrl: newPres.imagenUrl ?? fullProduct.imagenUrl, 
            unit: newPres.unidadVenta ?? "Unidad",
            conversionFactor: newPres.unidadesPorVenta 
          );

          provider.updatePairProduct(pair.sourceItem.id, newMatched);
          provider.updatePairPrice(pair.sourceItem.id, newPrice);
          provider.updatePairQuantity(pair.sourceItem.id, newQty);
        },
      ),
    );
  }

  void _openSearchModal(BuildContext context, MatchPair pair, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) => MatchingProductSearchModal(
        initialQuery: pair.sourceItem.fullName,
        isDark: isDark,
        onProductSelected: (product, categoryName) {
          Provider.of<MatchingProvider>(context, listen: false).updatePairProduct(pair.sourceItem.id, product);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchingProvider = Provider.of<MatchingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = !authProv.hasActiveContext;
    final isClient = authProv.isCommunityClient; 

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(isDark);
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(isClient ? "Completar mi Pedido" : "Cotización Inteligente", style: textTheme.displayMedium?.copyWith(color: textColor)),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: textColor),
          elevation: 0,
          actions: [
            if (matchingProvider.hasModifications)
              IconButton(
                icon: Icon(Icons.settings_backup_restore, color: isDark ? Colors.orange[300] : Colors.orangeAccent, size: 26),
                tooltip: "Reiniciar Análisis",
                onPressed: () => _resetToInitial(isDark),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: Text("${matchingProvider.matchedCount}/${matchingProvider.pairs.length} Listos", style: textTheme.titleMedium?.copyWith(color: textColor)),
                ),
              ),
            )
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
                        child: _buildEditableHeader(matchingProvider, isDark, textTheme, isGuest, isClient), 
                      ),
                      
                      if (matchingProvider.isLoading)
                        const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                bool isRepeated = matchingProvider.isProductRepeated(matchingProvider.pairs[i].selectedProduct?.presentationId);

                                return MatchingItemRow(
                                  pair: matchingProvider.pairs[i],
                                  index: i,
                                  isRepeated: isRepeated, 
                                  isClient: isClient, 
                                  onTapProduct: () => _openDetailsModal(context, matchingProvider.pairs[i]),
                                  onChangeRequest: () => _openSearchModal(context, matchingProvider.pairs[i], isDark),
                                  onDelete: () => matchingProvider.deletePair(matchingProvider.pairs[i].sourceItem.id),
                                  onUnlink: () => matchingProvider.unmatchItem(matchingProvider.pairs[i].sourceItem.id),
                                );
                              },
                              childCount: matchingProvider.pairs.length,
                            ),
                          ),
                        ),

                      if (!matchingProvider.isLoading && !isClient) 
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: TextButton.icon(
                                icon: Icon(Icons.add_circle_outline, size: 24, color: isDark ? Colors.blue[300] : Colors.blue),
                                label: Text("Agregar Fila Manual", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue)),
                                onPressed: () => matchingProvider.addManualRow(),
                              ),
                            ),
                          ),
                        ),
                        
                      const SliverToBoxAdapter(child: SizedBox(height: 100)), 
                    ],
                  ),
                ),
                MatchingSmartBottomBar(provider: matchingProvider, isDark: isDark, theme: textTheme), 
              ],
            ),
            
            if (matchingProvider.isSaving)
              Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
            
            if (_isFabOpen) GestureDetector(onTap: _toggleFab, child: Container(color: Colors.black87, width: double.infinity, height: double.infinity)),
            
            if (_isFabOpen) 
              Positioned(
                bottom: 190, right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isClient) ...[
                      MatchingSpeedDialButton(
                        icon: Icons.send, label: "Confirmar y Enviar Pedido", color: isDark ? Colors.green[400]! : Colors.green[700]!, isDark: isDark, theme: textTheme,
                        onTap: () => _handleActionWithConfirmation('client_send', isDark)
                      )
                    ] else ...[
                      MatchingSpeedDialButton(
                        icon: Icons.list_alt, label: "Guardar y ver Mesa de Trabajo", color: isDark ? Colors.blue[400]! : Colors.blue[800]!, isDark: isDark, theme: textTheme,
                        onTap: () => _handleActionWithConfirmation('save', isDark)
                      ),
                      const SizedBox(height: 20),
                      MatchingSpeedDialButton(
                        icon: Icons.picture_as_pdf, label: "Generar PDF Directo", color: isDark ? Colors.red[400]! : Colors.red[700]!, isDark: isDark, theme: textTheme,
                        onTap: () => _handleActionWithConfirmation('pdf', isDark)
                      ),
                      const SizedBox(height: 20),
                      MatchingSpeedDialButton(
                        icon: Icons.chat, label: "Enviar por WhatsApp", color: isDark ? Colors.green[400]! : Colors.green[600]!, isDark: isDark, theme: textTheme,
                        onTap: () => _handleActionWithConfirmation('whatsapp', isDark)
                      ),
                    ]
                  ],
                ),
              ),

            Positioned(
              bottom: 115, right: 16,
              child: FloatingActionButton(
                onPressed: _toggleFab,
                backgroundColor: _isFabOpen ? (isDark ? Colors.red[800] : Colors.red) : (isDark ? Colors.green[700] : Colors.green[700]),
                elevation: 6,
                child: RotationTransition(turns: _fabRotateAnim, child: Icon(_isFabOpen ? Icons.close : (isClient ? Icons.send : Icons.save), size: 30, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableHeader(MatchingProvider provider, bool isDark, TextTheme theme, bool isGuest, bool isClient) {
    return Container(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _isClientPanelExpanded,
              iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
              collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
              title: Text(isClient ? "Mis Datos y Colegio" : "Datos del Cliente y Colegio", style: theme.titleMedium?.copyWith(color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text("Toca para desplegar y editar", style: theme.bodyMedium?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey)),
              onExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
              children: [
                ManualQuoteInstitutionHeader(
                    schoolCtrl: _schoolCtrl,
                    gradeCtrl: _gradeCtrl,
                    isDark: isDark,
                  ),
                const SizedBox(height: 10),
                ManualQuoteClientHeader(
                  selectedClient: provider.selectedClient,
                  nameCtrl: _clientNameCtrl,
                  phoneCtrl: _clientPhoneCtrl,
                  dniCtrl: _clientDniCtrl,
                  addressCtrl: _clientAddressCtrl,
                  emailCtrl: _clientEmailCtrl,
                  notesCtrl: _clientNotesCtrl,
                  isNewClientMode: _updateClientData,
                  isDark: isDark,
                  isGuest: isGuest, 
                  onNewClientModeChanged: (v) { setState(() { _updateClientData = v ?? false; }); _updateHeader(); },
                  onSearchClientTap: isClient ? () {
                    CustomSnackBar.show(context, message: "Tu cuenta ya está vinculada automáticamente.", isError: false);
                  } : () => _showClientSearch(isDark),
                  onClearClient: isClient ? () {
                    CustomSnackBar.show(context, message: "No puedes desvincular tu propia cuenta.", isError: true);
                  } : _clearClient,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
        ],
      ),
    );
  }
}