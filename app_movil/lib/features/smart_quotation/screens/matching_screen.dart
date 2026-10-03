import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart'; 
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart'; 

import 'package:app_movil/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_item_row.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_product_search_modal.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_smart_bottom_bar.dart'; 

import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_client_header.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';   
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart'; 
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/client_orders_screen.dart'; 
import 'package:app_movil/core/screens/home_screen.dart'; 

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
    // 💡 NOTA: Este modal reutiliza el componente `ClientSearchModal` de la Cotización Manual.
    // Esto garantiza un diseño consistente, lógica independiente (estado aislado por widget)
    // y carga automática de clientes recientes sin conflictos de estado entre pantallas.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientSearchModal(
        onClientSelected: (client) {
          _selectClient(client);
        }
      ),
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

  Future<void> _openDetailsModal(BuildContext context, MatchPair pair) async {
    if (pair.selectedProduct == null) return;
    
    try {
      final inventoryProv = Provider.of<InventoryProvider>(context, listen: false);
      Product? fullProduct;
      
      try {
        fullProduct = await inventoryProv.getFullProductWithFallback(pair.selectedProduct!.productId);
      } catch (_) {
        // Fallback si incluso getFullProductWithFallback falla catastróficamente (ej. no existe ni en DB)
        fullProduct = null;
      }
      
      if (!context.mounted) return;

      if (fullProduct == null || fullProduct.presentaciones.isEmpty) {
        // FASE 3 FIX: Inyectar presentación dinámica basada en el MatchedProduct (Fallback)
        fullProduct = Product(
          id: pair.selectedProduct!.productId, 
          nombre: pair.selectedProduct!.productName, 
          categoriaId: fullProduct?.categoriaId ?? 0, 
          imagenUrl: pair.selectedProduct!.imageUrl, 
          marcaId: fullProduct?.marcaId, 
          presentaciones: [
            ProductPresentation(
              id: pair.selectedProduct!.presentationId, 
              unidadVenta: pair.selectedProduct!.unit, 
              nombreEspecifico: pair.selectedProduct!.specificName, 
              precioVentaFinal: pair.selectedProduct!.price, 
              precioOferta: pair.selectedProduct!.offerPrice,
              stockActual: pair.selectedProduct!.stock, 
              unidadesPorLote: pair.selectedProduct!.conversionFactor, 
              imagenUrl: pair.selectedProduct!.imageUrl,
            )
          ]
        );
      }

      final currentPres = fullProduct.presentaciones.firstWhere(
        (p) => p.id == pair.selectedProduct!.presentationId, 
        orElse: () => fullProduct!.presentaciones.first
      );
      
      final wrapper = InventoryWrapper(product: fullProduct, presentation: currentPres);
      final String? brandName = fullProduct.marcaId != null ? inventoryProv.getBrandName(fullProduct.marcaId) : pair.selectedProduct!.brand; 
      
      // Capture the final Product explicitly to prevent issues with closures in the modal callback
      final capturedProduct = fullProduct;

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
          availableBundles: Provider.of<MatchingProvider>(context, listen: false).activeBundles,
          bundleItemsCache: Provider.of<MatchingProvider>(context, listen: false).bundleItemsCache,
          onSave: (newPres, newQty, newPrice, _) { 
            final provider = Provider.of<MatchingProvider>(context, listen: false);
            
            final newMatched = MatchedProduct(
              productId: capturedProduct.id, 
              presentationId: newPres.id!, 
              fullName: capturedProduct.nombre, 
              productName: capturedProduct.nombre, 
              specificName: newPres.nombreEspecifico, 
              brand: brandName, 
              price: newPres.precioVentaFinal, 
              offerPrice: newPres.precioOferta, 
              stock: newPres.stockActual, 
              imageUrl: newPres.imagenUrl ?? capturedProduct.imagenUrl, 
              unit: newPres.unidadVenta ?? "Unidad",
              conversionFactor: newPres.unidadesPorVenta 
            );

            provider.updatePairProduct(pair.sourceItem.id, newMatched);
            provider.updatePairPrice(pair.sourceItem.id, newPrice);
            provider.updatePairQuantity(pair.sourceItem.id, newQty);
          },
        ),
      );
    } catch (e) {
      debugPrint("Error abriendo detalle de producto: $e");
      CustomSnackBar.show(context, message: "Ocurrió un error al intentar abrir el detalle del producto.", isError: true);
    }
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

  void _confirmAndDeletePair(BuildContext context, MatchPair pair, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 10),
            const Text("Eliminar Producto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("¿Estás seguro de que deseas eliminar '${pair.sourceItem.fullName}' de la lista?", style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<MatchingProvider>(context, listen: false).deletePair(pair.sourceItem.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Eliminar"),
          ),
        ],
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
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: SizedBox(
            width: double.infinity,
            child: MarqueeText(
              text: isClient ? "Completar mi Pedido" : "Cotización Inteligente", 
              style: textTheme.displayMedium?.copyWith(color: textColor, fontSize: 18),
            ),
          ),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("${matchingProvider.matchedCount}/${matchingProvider.pairs.length} Listos", style: textTheme.titleMedium?.copyWith(color: textColor)),
                  ),
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
                                // Agrupamiento Visual de Paquetes
                                // En lugar de renderizar uno por uno, vamos a agrupar los que tienen bundleId igual.
                                // Para no complicar la lista indexada, si es el PRIMER item de un bundle, dibujamos todo el contenedor del bundle.
                                // Si es un item de un bundle que ya no es el primero, retornamos SizedBox vacío (ya se dibujó).
                                final pair = matchingProvider.pairs[i];
                                
                                if (pair.bundleId != null) {
                                  // ¿Es el primero de su grupo en la lista?
                                  final isFirstInBundle = matchingProvider.pairs.indexWhere((p) => p.bundleId == pair.bundleId) == i;
                                  if (!isFirstInBundle) return const SizedBox.shrink();
                                  
                                  // Dibujar grupo completo
                                  final bundlePairs = matchingProvider.pairs.where((p) => p.bundleId == pair.bundleId).toList();
                                  final bundleModel = matchingProvider.activeBundles.firstWhere((b) => b.id == pair.bundleId);
                                  
                                  double totalSavings = bundlePairs.fold(0.0, (sum, p) => sum + (p.originalUnitPrice * p.selectedQuantity)) - bundleModel.precioVentaTotal;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.amber.shade300, width: 1.5),
                                      borderRadius: BorderRadius.circular(16),
                                      color: isDark ? Colors.amber.withValues(alpha: 0.03) : Colors.amber.withValues(alpha: 0.05),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.2),
                                            border: Border(bottom: BorderSide(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade200, width: 1))
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Padding(
                                                      padding: EdgeInsets.only(top: 2),
                                                      child: Icon(Icons.stars, color: Colors.amber, size: 20),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text("✨ Agrupados en ${bundleModel.nombrePaquete}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                          if (bundleModel.descripcion != null && bundleModel.descripcion!.isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(bundleModel.descripcion!, style: TextStyle(color: isDark ? Colors.amber.shade300 : Colors.amber.shade800, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton.icon(
                                                onPressed: () => matchingProvider.toggleBundleGrouping(bundleModel.id, false),
                                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: const Size(0, 0), backgroundColor: Colors.red.withValues(alpha: 0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                icon: const Icon(Icons.link_off, size: 14, color: Colors.red),
                                                label: const Text("Desarmar", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                                              )
                                            ],
                                          ),
                                        ),
                                        if (totalSavings > 0)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.local_offer, color: Colors.green[600], size: 14),
                                                  const SizedBox(width: 6),
                                                  Text("Ahorro Múltiple de S/ ${totalSavings.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ...bundlePairs.map((bp) {
                                          int originalIndex = matchingProvider.pairs.indexOf(bp);
                                          bool isRepeated = matchingProvider.isProductRepeated(bp.selectedProduct?.presentationId);
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: MatchingItemRow(
                                              pair: bp,
                                              index: originalIndex,
                                              isRepeated: isRepeated, 
                                              isClient: isClient, 
                                              onTapProduct: () => _openDetailsModal(context, bp),
                                              onChangeRequest: () => _openSearchModal(context, bp, isDark),
                                              onDelete: () => _confirmAndDeletePair(context, bp, isDark),
                                              onUnlink: () => matchingProvider.unmatchItem(bp.sourceItem.id),
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  );
                                }

                                // Render normal
                                bool isRepeated = matchingProvider.isProductRepeated(pair.selectedProduct?.presentationId);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: MatchingItemRow(
                                    pair: pair,
                                    index: i,
                                    isRepeated: isRepeated, 
                                    isClient: isClient, 
                                    onTapProduct: () => _openDetailsModal(context, pair),
                                    onChangeRequest: () => _openSearchModal(context, pair, isDark),
                                    onDelete: () => _confirmAndDeletePair(context, pair, isDark),
                                    onUnlink: () => matchingProvider.unmatchItem(pair.sourceItem.id),
                                  ),
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
            
            IgnorePointer(
              ignoring: !_isFabOpen,
              child: FadeTransition(
                opacity: _fabAnimationCtrl,
                child: GestureDetector(
                  onTap: _toggleFab, 
                  child: Container(color: Colors.black87, width: double.infinity, height: double.infinity)
                ),
              ),
            ),
            
            Positioned(
              bottom: 190, right: 16,
              child: IgnorePointer(
                ignoring: !_isFabOpen,
                child: FadeTransition(
                  opacity: _fabAnimationCtrl,
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