import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/quick_sale_provider.dart';
import '../providers/quick_search_provider.dart'; 
import '../../../providers/auth_provider.dart'; 
import '../../../models/inventory_wrapper.dart';

import '../../../widgets/custom_snackbar.dart';
import '/screens/scanner/barcode_scanner_screen.dart';
import '../../../screens/catalog/catalog_screen.dart';

import '../widgets/quick_sale/quick_sale_header.dart';
import '../widgets/quick_sale/quick_sale_cart_item.dart';
import '../widgets/quick_sale/quick_sale_detail_modal.dart';
import '../widgets/quick_sale/quick_checkout_modal.dart';
import '../widgets/quick_sale/quick_search_result_tile.dart';

class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _saleCompleted = false; 

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
        onConfirm: (product, newQty, newPrice) {
          final error = provider.updateItemFromModal(product, newQty, newPrice);
          if (error != null) {
             CustomSnackBar.show(context, message: error, isError: true);
          }
        },
      )
    );
  }

  void _processToCheckout() {
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

  @override
  Widget build(BuildContext context) {
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final searchProv = Provider.of<QuickSearchProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF1A1A24) : Colors.pinkAccent;

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
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(quickProv.saleNote != null && quickProv.saleNote!.isNotEmpty ? Icons.event_note : Icons.note_add, size: 28),
                tooltip: "Añadir Nota",
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
            if (!quickProv.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 28),
                  onPressed: () { 
                    quickProv.clearCart(); 
                    CustomSnackBar.show(context, message: "Caja restablecida por completo", isError: false); 
                  },
                  tooltip: "Limpiar Todo",
                ),
              )
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              QuickSaleHeader(isGuest: isGuest, isDark: isDark),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: appBarColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre o código...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
                    prefixIcon: const Icon(Icons.search, color: Colors.white, size: 24),
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (searchProv.isSearching) 
                          Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                        else if (_searchCtrl.text.isNotEmpty) 
                          IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { _searchCtrl.clear(); searchProv.clearSearch(); }),
                        IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26), onPressed: _scanBarcode),
                      ],
                    )
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              Expanded(
                child: searchProv.searchResults.isNotEmpty
                  ? _buildSearchResults(searchProv, isDark)
                  : _buildCart(quickProv, isDark),
              ),

              if (quickProv.cartItems.isNotEmpty && searchProv.searchResults.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))]),
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
                          style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.pinkAccent[400] : Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: isDark ? 0 : 4, padding: const EdgeInsets.symmetric(horizontal: 10)),
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

  Widget _buildSearchResults(QuickSearchProvider searchProv, bool isDark) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
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
          Expanded(
            child: ListView.separated(
              itemCount: searchProv.searchResults.length + (searchProv.hasMoreData ? 1 : 1),
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              itemBuilder: (ctx, i) {
                if (i == searchProv.searchResults.length) {
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
                return QuickSearchResultTile(item: searchProv.searchResults[i], onTap: () => _addToCart(searchProv.searchResults[i]));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCart(QuickSaleProvider quickProv, bool isDark) {
    if (quickProv.cartItems.isEmpty) {
      return Center(
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
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 30),
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
            // 🔥 Atrapamos y mostramos el error si el stock llegó al límite
            final error = quickProv.updateQuantity(item.presentationId, qty + 1, item.stock);
            if (error != null) CustomSnackBar.show(context, message: error, isError: true);
          },
          onDecrease: () {
            final error = quickProv.updateQuantity(item.presentationId, qty - 1, item.stock);
            if (error != null) CustomSnackBar.show(context, message: error, isError: true);
          },
        );
      },
    );
  }
}