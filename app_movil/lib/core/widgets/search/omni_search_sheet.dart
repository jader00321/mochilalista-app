import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/search/omni_search_models_and_engine.dart';
import 'package:app_movil/core/widgets/search/omni_search_result_cards.dart';
import 'package:app_movil/core/widgets/search/omni_search_sheet_controls.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

class OmniSearchSheet extends StatefulWidget {
  const OmniSearchSheet({super.key});

  @override
  State<OmniSearchSheet> createState() => _OmniSearchSheetState();
}

class _OmniSearchSheetState extends State<OmniSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _clientResults = [];
  List<Map<String, dynamic>> _quoteResults = [];
  List<Map<String, dynamic>> _saleResults = [];

  OmniSearchCounts _dbCounts = const OmniSearchCounts();

  bool _isSearching = false;
  String _activeCategory = 'all'; // all, products, clients, quotes, sales
  OmniSortOption _sortOption = OmniSortOption.relevance;
  final Set<String> _expandedKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDatabaseCounts();
      _loadRecentDefaults();
      // Coordinación de foco para entrada limpia y continua sin doble salto
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseCounts() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;
      final counts = await OmniSearchEngine.loadDatabaseCounts(db, businessId);
      if (mounted) {
        setState(() => _dbCounts = counts);
      }
    } catch (e) {
      debugPrint("Error cargando conteos reales en omnicanal: $e");
    }
  }

  Future<void> _loadRecentDefaults() async {
    if (_searchCtrl.text.trim().isNotEmpty) return;
    setState(() => _isSearching = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;
      final results = await OmniSearchEngine.loadRecentDefaults(
        db,
        businessId,
        _activeCategory,
      );

      if (mounted && _searchCtrl.text.trim().isEmpty) {
        setState(() {
          _productResults = results.products;
          _clientResults = results.clients;
          _quoteResults = results.quotes;
          _saleResults = results.sales;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      await _loadRecentDefaults();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;
      final results = await OmniSearchEngine.performSearch(
        db,
        businessId,
        term,
        _activeCategory,
      );

      if (mounted && _searchCtrl.text.trim() == term) {
        setState(() {
          _productResults = results.products;
          _clientResults = results.clients;
          _quoteResults = results.quotes;
          _saleResults = results.sales;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleExpanded(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  Future<void> _navigateToProduct(Map<String, dynamic> p) async {
    final nav = Navigator.of(context);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final prodId = p['product_id'] as int;
    final presId = p['presentation_id'] as int;

    final fullProd = await invProv.getFullProductWithFallback(prodId);
    if (!mounted) return;
    nav.pop();
    if (fullProd != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: fullProd,
            initialPresentationId: presId,
            heroTag: 'omni_${prodId}_$presId',
          ),
        ),
      );
    }
  }

  Future<void> _navigateToClient(Map<String, dynamic> c) async {
    final nav = Navigator.of(context);
    final clientId = c['id'] as int;
    final clientModel = await ClientService().getClientById(clientId);
    if (!mounted) return;
    nav.pop();
    if (clientModel != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientDetailScreen(client: clientModel),
        ),
      );
    }
  }

  void _navigateToQuote(Map<String, dynamic> q) {
    final nav = Navigator.of(context);
    final quoteId = q['id'] as int;
    final clientName = q['client_name'];
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) =>
            QuotationDetailScreen(quotationId: quoteId, clientName: clientName),
      ),
    );
  }

  void _navigateToSale(Map<String, dynamic> s) {
    final nav = Navigator.of(context);
    final saleId = s['id'] as int;
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => SaleHistoryDetailScreen(saleId: saleId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMatches =
        _productResults.length +
        _clientResults.length +
        _quoteResults.length +
        _saleResults.length;

    final query = _searchCtrl.text;
    final sortedProducts = OmniSearchEngine.sortResults(
      _productResults,
      'products',
      _sortOption,
      query,
    );
    final sortedClients = OmniSearchEngine.sortResults(
      _clientResults,
      'clients',
      _sortOption,
      query,
    );
    final sortedQuotes = OmniSearchEngine.sortResults(
      _quoteResults,
      'quotes',
      _sortOption,
      query,
    );
    final sortedSales = OmniSearchEngine.sortResults(
      _saleResults,
      'sales',
      _sortOption,
      query,
    );

    final bool isQueryEmpty = query.trim().isEmpty;

    final listItems = OmniSearchEngine.buildVirtualizedItems(
      activeCategory: _activeCategory,
      sortedProducts: sortedProducts,
      sortedClients: sortedClients,
      sortedQuotes: sortedQuotes,
      sortedSales: sortedSales,
    );

    return InteractiveSheetWrapper(
      title: "Búsqueda Omnicanal Local",
      maxHeightFactor: 0.92,
      maintainFixedHeightOnKeyboard: true,
      applyEffectiveBottomPadding: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              autofocus: false,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: "Escribe producto, cliente, cotización o folio...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadRecentDefaults();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _performSearch,
            ),
          ),
          OmniCategoryChipsBar(
            activeCategory: _activeCategory,
            counts: _dbCounts,
            isDark: isDark,
            onCategoryChanged: (id) {
              setState(() => _activeCategory = id);
              if (_searchCtrl.text.trim().isEmpty) {
                _loadRecentDefaults();
              } else {
                _performSearch(_searchCtrl.text);
              }
            },
          ),
          const SizedBox(height: 12),
          OmniSortBarRow(
            isQueryEmpty: isQueryEmpty,
            sortOption: _sortOption,
            isDark: isDark,
            onSortChanged: (opt) => setState(() => _sortOption = opt),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : totalMatches == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No se encontraron resultados para '${_searchCtrl.text}'",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Builder(
                    builder: (ctx) {
                      final bottomKeyboardInset = MediaQuery.viewInsetsOf(
                        ctx,
                      ).bottom;
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                          bottom: bottomKeyboardInset + 24,
                        ),
                        itemCount: listItems.length,
                        itemBuilder: (context, index) {
                          final item = listItems[index];
                          if (item is OmniHeaderItem) {
                            return OmniSectionHeader(
                              title: item.title,
                              count: item.count,
                              icon: item.icon,
                              isDark: isDark,
                            );
                          }
                          if (item is OmniProductItem) {
                            final p = item.data;
                            final key = "prod_${p['presentation_id']}";
                            return OmniProductResultCard(
                              data: p,
                              isDark: isDark,
                              isExpanded: _expandedKeys.contains(key),
                              onToggleExpand: () => _toggleExpanded(key),
                              onOpen: () => _navigateToProduct(p),
                            );
                          }
                          if (item is OmniClientItem) {
                            final c = item.data;
                            final key = "client_${c['id']}";
                            return OmniClientResultCard(
                              data: c,
                              isDark: isDark,
                              isExpanded: _expandedKeys.contains(key),
                              onToggleExpand: () => _toggleExpanded(key),
                              onOpen: () => _navigateToClient(c),
                            );
                          }
                          if (item is OmniQuoteItem) {
                            final q = item.data;
                            final key = "quote_${q['id']}";
                            return OmniQuoteResultCard(
                              data: q,
                              isDark: isDark,
                              isExpanded: _expandedKeys.contains(key),
                              onToggleExpand: () => _toggleExpanded(key),
                              onOpen: () => _navigateToQuote(q),
                            );
                          }
                          if (item is OmniSaleItem) {
                            final s = item.data;
                            final key = "sale_${s['id']}";
                            return OmniSaleResultCard(
                              data: s,
                              isDark: isDark,
                              isExpanded: _expandedKeys.contains(key),
                              onToggleExpand: () => _toggleExpanded(key),
                              onOpen: () => _navigateToSale(s),
                            );
                          }
                          if (item is OmniSpacerItem) {
                            return const SizedBox(height: 12);
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
