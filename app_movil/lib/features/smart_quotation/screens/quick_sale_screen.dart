import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart'; 
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';

import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart';

class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _saleCompleted = false; 
  bool _isOffersExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
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
          "Estás en el Modo Exploración.\n\nPuedes buscar productos y añadirlos al carrito para probar la interfaz, pero para Procesar el Cobro o Buscar Clientes Reales necesitas tener un negocio registrado.\n\nVe a tu Perfil para crear tu negocio.",
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final searchProv = Provider.of<QuickSearchProvider>(context, listen: false);
      if (query.isNotEmpty) {
        searchProv.searchProducts(query);
      } else {
        searchProv.clearSearch();
      }
    });
  }

  void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(isFromQuickSale: true)),
    ).then((_) {
      _searchCtrl.clear();
      if (!mounted) return;
      Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    });
  }

  void _addToCart(InventoryWrapper item) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final error = quickProv.addToCart(item);
    
    // 🔥 Atrapamos el error amigable del Provider
    if (error != null) {
      CustomSnackBar.show(context, message: error, isError: true);
      return;
    }
    
    _searchCtrl.clear();
    Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    FocusScope.of(context).unfocus();
    CustomSnackBar.show(context, message: "Agregado: ${item.product.nombre}", isError: false);
  }

  void _openDetailModal(QuickSaleProvider provider, int presentationId) {
    FocusScope.of(context).unfocus(); // Evita que el teclado se reabra al cerrar el modal

    final item = provider.cartItems.firstWhere((p) => p.presentationId == presentationId);
    final qty = provider.getQuantity(presentationId);
    final effectivePrice = provider.getEffectivePrice(presentationId);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickSaleDetailModal(
        product: item,
        initialQty: qty,
        initialOverridePrice: effectivePrice,
        onConfirm: (oldPresentationId, product, newQty, newPrice) {
          final error = provider.updateItemFromModal(oldPresentationId, product, newQty, newPrice);
          if (error != null) {
             CustomSnackBar.show(context, message: error, isError: true);
          }
        },
      )
    );
  }

  void _processToCheckout() {
    FocusScope.of(context).unfocus(); // Evitar reapertura del teclado al cerrar checkout
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<QuickSaleProvider>(context, listen: false);
    if (provider.isEmpty) return;
    
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const QuickCheckoutModal(),
      ),
    ).then((wasSaleSuccessful) {
      if (wasSaleSuccessful == true) {
        _saleCompleted = true;
      }
    });
  }

  Widget _buildNotesDrawer(BuildContext context, QuickSaleProvider prov, bool isDark) {
    final ctrl = TextEditingController(text: prov.saleNote)..selection = TextSelection.collapsed(offset: prov.saleNote?.length ?? 0);
    
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: isDark ? Colors.amber[300] : Colors.amber[700], size: 32),
                  const SizedBox(width: 12),
                  Text("Nota de Venta", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Agrega un comentario, referencia o detalle especial para esta venta rápida. Se guardará en tu historial de ventas.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: ctrl,
                maxLines: 5,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Escribe tu nota aquí...",
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  suffixIcon: ctrl.text.isNotEmpty ? IconButton(
                    icon: Icon(Icons.cancel, color: isDark ? Colors.grey[600] : Colors.grey),
                    onPressed: () {
                      ctrl.clear();
                      prov.clearSaleNote();
                    },
                    tooltip: "Borrar todo",
                  ) : null
                ),
                onChanged: (val) => prov.setClientInfo(
                  id: prov.clientId, 
                  name: prov.clientName, 
                  phone: prov.clientPhone, 
                  clientNote: prov.clientNote, 
                  saleNote: val.trim().isEmpty ? null : val, 
                  saldo: prov.clientSaldo
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check, size: 20),
                  label: const Text("Confirmar Nota", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCartModal(BuildContext context, QuickSaleProvider prov, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.8, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: (scale - 0.8) * 5, // fade in
              child: child,
            ),
          );
        },
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("¿Vaciar Caja?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
            ],
          ),
          content: Text(
            "¿Estás seguro de que deseas eliminar todos los productos de la lista actual? Esta acción no se puede deshacer.",
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                prov.clearCart();
                Navigator.pop(ctx);
                CustomSnackBar.show(context, message: "Caja restablecida por completo", isError: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Sí, Vaciar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final searchProv = Provider.of<QuickSearchProvider>(context);
    final promoProv = Provider.of<PromotionProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF1A1A24) : const Color(0xFF2D3748);

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _saleCompleted);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: false, 
        
        endDrawer: _buildNotesDrawer(context, quickProv, isDark),
        appBar: AppBar(
          title: const Text("Caja Rápida", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context, _saleCompleted),
          ),
          actions: [
            if (!quickProv.isEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 28),
                onPressed: () => _showClearCartModal(context, quickProv, isDark),
                tooltip: "Limpiar Todo",
              ),
            Builder(
              builder: (ctx) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(quickProv.saleNote != null && quickProv.saleNote!.isNotEmpty ? Icons.event_note : Icons.note_add, size: 28),
                  tooltip: "Añadir Nota",
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: CustomScrollView(
                    slivers: [
                    SliverToBoxAdapter(
                      child: QuickSaleHeader(isGuest: isGuest, isDark: isDark),
                    ),

                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      actions: const [SizedBox.shrink()],
                      backgroundColor: appBarColor,
                      elevation: 0,
                      toolbarHeight: 90,
                      flexibleSpace: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: appBarColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: false,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre o código...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                            prefixIcon: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white, size: 24),
                              onPressed: () {
                                _searchCtrl.clear();
                                Provider.of<QuickSearchProvider>(context, listen: false).searchProducts('');
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                                  onPressed: _scanBarcode,
                                  tooltip: "Escanear código",
                                ),
                              ),
                            )
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                    ),

                    if (searchProv.categories.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          height: 50,
                          margin: const EdgeInsets.only(top: 10, bottom: 5),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: const Text("Todas"),
                                  selected: searchProv.selectedCategoryId == null,
                                  onSelected: (val) {
                                    if (val) searchProv.selectCategory(null);
                                  },
                                  selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
                                  labelStyle: TextStyle(color: (searchProv.selectedCategoryId == null) ? (isDark ? Colors.white : Colors.blue[900]) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontWeight: FontWeight.bold),
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                ),
                              ),
                              ...searchProv.categories.map((cat) {
                                final isSelected = searchProv.selectedCategoryId == cat.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(cat.nombre),
                                    selected: isSelected,
                                    onSelected: (val) {
                                      if (val) searchProv.selectCategory(cat.id);
                                    },
                                    selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
                                    labelStyle: TextStyle(color: isSelected ? (isDark ? Colors.white : Colors.blue[900]) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontWeight: FontWeight.bold),
                                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                    if (promoProv.bundles.isNotEmpty && searchProv.searchResults.isEmpty)
                      SliverToBoxAdapter(
                        child: Builder(builder: (ctx) {
                          final now = DateTime.now();
                          final validBundles = promoProv.bundles.where((b) {
                            if (!b.activo) return false;
                            if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) return false;
                            if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
                            final maxStock = promoProv.calculateBundleMaxStock(b.id);
                            return maxStock > 0;
                          }).toList();

                          if (validBundles.isEmpty) return const SizedBox();

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            color: isDark ? appBarColor : Colors.grey[100],
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => setState(() => _isOffersExpanded = !_isOffersExpanded),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                          child: Text("🔥 Ofertas Disponibles (${validBundles.length})", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                                        ),
                                        const Spacer(),
                                        Icon(_isOffersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isDark ? Colors.white70 : Colors.grey[700], size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isOffersExpanded)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: validBundles.length,
                                      itemBuilder: (ctx, i) {
                                        final bundle = validBundles[i];
                                        final maxStock = promoProv.calculateBundleMaxStock(bundle.id);
                                        
                                        IconData iconData = Icons.inventory_2;
                                        Color iconColor = Colors.amberAccent;
                                        String prefix = "Paquete";
                                        if (bundle.tipoPromocion == 'flash') {
                                          iconData = Icons.bolt; iconColor = Colors.yellowAccent; prefix = "Flash";
                                        } else if (bundle.tipoPromocion == 'liquidez_costo') {
                                          iconData = Icons.water_drop; iconColor = Colors.lightBlueAccent; prefix = "Liquidez";
                                        } else if (bundle.tipoPromocion == '2x1') {
                                          iconData = Icons.exposure_plus_2; iconColor = Colors.greenAccent; prefix = "2x1";
                                        } else if (bundle.tipoPromocion == 'volumen') {
                                          iconData = Icons.shopping_cart; iconColor = Colors.deepPurpleAccent; prefix = "Mayoreo";
                                        } else if (bundle.tipoPromocion == 'escolar') {
                                          iconData = Icons.school; iconColor = Colors.tealAccent; prefix = "Escolar";
                                        }
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                                                child: Icon(iconData, color: iconColor, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(bundle.nombrePaquete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                    if (bundle.descripcion != null && bundle.descripcion!.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                                                        child: Text(bundle.descripcion!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                                          child: Text(prefix, style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(currency.format(bundle.precioVentaTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(width: 8),
                                                        Text("Stock: $maxStock", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                                                onPressed: () {
                                                  final error = quickProv.addBundleToCart(bundle, maxStock);
                                                  if (error != null) {
                                                    CustomSnackBar.show(context, message: error, isError: true);
                                                  } else {
                                                    CustomSnackBar.show(context, message: "Paquete agregado al carrito.", isError: false);
                                                  }
                                                },
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),

                    if (searchProv.searchResults.isNotEmpty)
                      ..._buildSearchResultsSlivers(searchProv, isDark)
                    else
                      ..._buildCartSlivers(quickProv, promoProv, isDark),
                  ],
                ),
              ),
              ),

              if (quickProv.cartItems.isNotEmpty && searchProv.searchResults.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -5))]),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("TOTAL A COBRAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(currency.format(quickProv.totalToPay), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 60, width: 140, 
                        child: ElevatedButton.icon(
                          onPressed: _processToCheckout, 
                          icon: const Icon(Icons.payment, size: 22),
                          label: const Text("COBRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                          style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.pink[600] : const Color(0xFFD81B60), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: isDark ? 0 : 4, padding: const EdgeInsets.symmetric(horizontal: 10)),
                        ),
                      )
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSearchResultsSlivers(QuickSearchProvider searchProv, bool isDark) {
    return [
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${searchProv.searchResults.length} resultados encontrados", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14)),
              PopupMenuButton<String>(
                color: Theme.of(context).colorScheme.surface,
                child: Row(children: [Icon(Icons.sort, size: 18, color: isDark ? Colors.blue[300] : Colors.blue), const SizedBox(width: 6), Text("Ordenar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 14))]),
                onSelected: (val) => searchProv.sortResults(val),
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'nombre_asc', child: Text("Alfabético (A-Z)", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  PopupMenuItem(value: 'precio_desc', child: Text("Mayor Precio", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  PopupMenuItem(value: 'precio_asc', child: Text("Menor Precio", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                ],
              )
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            if (i == searchProv.searchResults.length * 2) {
              if (searchProv.hasMoreData) {
                WidgetsBinding.instance.addPostFrameCallback((_) => searchProv.loadMore());
                return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
              } else {
                return Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CatalogScreen()));
                    }, 
                    icon: const Icon(Icons.inventory_2, size: 24), 
                    label: const Text("Ir al Catálogo Completo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                );
              }
            }
            if (i.isOdd) {
              return Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]);
            }
            final index = i ~/ 2;
            return QuickSearchResultTile(item: searchProv.searchResults[index], onTap: () => _addToCart(searchProv.searchResults[index]));
          },
          childCount: searchProv.searchResults.length * 2 + (searchProv.hasMoreData ? 1 : 1),
        ),
      ),
    ];
  }

  List<Widget> _buildCartSlivers(QuickSaleProvider quickProv, PromotionProvider promoProv, bool isDark) {
    if (quickProv.cartItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.point_of_sale, size: 90, color: isDark ? Colors.white10 : Colors.pink[100]),
                const SizedBox(height: 20),
                Text("Caja Libre", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Busca un producto para empezar a cobrar", style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        )
      ];
    }

    String? upsellMessage;
    for (var item in quickProv.cartItems) {
       for (var bundle in promoProv.bundles) {
          if (bundle.activo) {
             final bItems = promoProv.getItemsForBundle(bundle.id);
             if (bItems.any((b) => b.presentacionId == item.presentationId)) {
                upsellMessage = "¡Upsell! Cambia ${item.productName} por el paquete '${bundle.nombrePaquete}' y aumenta el ticket promedio.";
                break;
             }
          }
       }
       if (upsellMessage != null) break;
    }

    return [
      if (upsellMessage != null)
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(upsellMessage, style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontWeight: FontWeight.bold))),
              ],
            )
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 16, bottom: 30),
        sliver: SliverReorderableList(
          itemCount: quickProv.cartItems.length,
          onReorder: (oldIndex, newIndex) => quickProv.reorderCart(oldIndex, newIndex),
          itemBuilder: (ctx, i) {
            final item = quickProv.cartItems[i];
            final qty = quickProv.getQuantity(item.presentationId);
            final price = quickProv.getEffectivePrice(item.presentationId);

            return QuickSaleCartItem(
              key: ValueKey(item.presentationId),
              product: item,
              quantity: qty,
              effectivePrice: price,
              onTap: () => _openDetailModal(quickProv, item.presentationId),
              onIncrease: () {
                final error = quickProv.updateQuantity(item.presentationId, qty + 1, item.stock);
                if (error != null) CustomSnackBar.show(context, message: error, isError: true);
              },
              onDecrease: () {
                final error = quickProv.updateQuantity(item.presentationId, qty - 1, item.stock);
                if (error != null) CustomSnackBar.show(context, message: error, isError: true);
              },
              onDelete: () => quickProv.removeItem(item.presentationId),
            );
          },
        ),
      ),
    ];
  }
}