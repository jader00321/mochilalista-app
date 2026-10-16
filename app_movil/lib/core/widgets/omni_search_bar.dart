import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/product_detail_modal.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';

class OmniSearchBar extends StatelessWidget {
  final VoidCallback? onBarcodeTap;

  const OmniSearchBar({super.key, this.onBarcodeTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openOmniSearchModal(context),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Buscar productos, clientes, ventas...",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onBarcodeTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBarcodeTap,
                tooltip: "Escanear código de barras",
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openOmniSearchModal(BuildContext context) {
    HapticFeedback.lightImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => const _OmniSearchSheet(),
    );
  }
}

class _OmniSearchSheet extends StatefulWidget {
  const _OmniSearchSheet();

  @override
  State<_OmniSearchSheet> createState() => _OmniSearchSheetState();
}

class _OmniSearchSheetState extends State<_OmniSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _clientResults = [];
  List<Map<String, dynamic>> _quoteResults = [];
  List<Map<String, dynamic>> _saleResults = [];

  bool _isSearching = false;
  String _activeCategory = 'all'; // all, products, clients, quotes, sales

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      if (mounted) {
        setState(() {
          _productResults.clear();
          _clientResults.clear();
          _quoteResults.clear();
          _saleResults.clear();
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);

    try {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;

      // 1. Productos
      final productsRaw = await db.rawQuery('''
        SELECT p.id as product_id, p.nombre as producto_nombre, m.nombre as marca_nombre,
               pr.id as presentation_id, pr.nombre_especifico, pr.precio_venta_final, pr.stock_actual,
               pr.unidad_venta, pr.unidades_por_venta, pr.imagen_url, p.imagen_url as p_img
        FROM presentaciones_producto pr
        JOIN productos p ON pr.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND (p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.codigo_barras LIKE ?)
        LIMIT 6
      ''', [businessId, '%$term%', '%$term%', '%$term%']);

      // 2. Clientes
      final clientsRaw = await db.rawQuery('''
        SELECT id, nombre_completo, telefono, numero_documento, saldo_a_favor, total_deuda, nivel_confianza
        FROM clientes
        WHERE negocio_id = ? AND (nombre_completo LIKE ? OR telefono LIKE ? OR numero_documento LIKE ?)
        LIMIT 6
      ''', [businessId, '%$term%', '%$term%', '%$term%']);

      // 3. Cotizaciones
      final quotesRaw = await db.rawQuery('''
        SELECT id, client_name, client_id, total_amount, status, created_at
        FROM smart_quotations
        WHERE negocio_id = ? AND (client_name LIKE ? OR id LIKE ?)
        ORDER BY id DESC
        LIMIT 6
      ''', [businessId, '%$term%', '%$term%']);

      // 4. Ventas
      final salesRaw = await db.rawQuery('''
        SELECT v.id, v.numero_secuencial, v.monto_total, v.fecha_venta, v.estado_pago,
               c.nombre_completo as cliente_nombre
        FROM ventas v
        LEFT JOIN clientes c ON v.cliente_id = c.id
        WHERE v.negocio_id = ? AND (c.nombre_completo LIKE ? OR v.numero_secuencial LIKE ?)
        ORDER BY v.id DESC
        LIMIT 6
      ''', [businessId, '%$term%', '%$term%']);

      if (mounted) {
        setState(() {
          _productResults = List.from(productsRaw);
          _clientResults = List.from(clientsRaw);
          _quoteResults = List.from(quotesRaw);
          _saleResults = List.from(salesRaw);
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMatches = _productResults.length +
        _clientResults.length +
        _quoteResults.length +
        _saleResults.length;

    return InteractiveSheetWrapper(
      title: "Búsqueda Omnicanal Local",
      maxHeightFactor: 0.9,
      applyEffectiveBottomPadding: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Input de búsqueda
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
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: "Escribe un producto, cliente o folio...",
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
                        _performSearch('');
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

        // Filtros de segmento
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('all', 'Todos ($totalMatches)', isDark),
              const SizedBox(width: 8),
              _buildCategoryChip(
                'products',
                '📦 Productos (${_productResults.length})',
                isDark,
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                'clients',
                '👤 Clientes (${_clientResults.length})',
                isDark,
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                'quotes',
                '📝 Cotizaciones (${_quoteResults.length})',
                isDark,
              ),
              const SizedBox(width: 8),
              _buildCategoryChip(
                'sales',
                '🧾 Ventas (${_saleResults.length})',
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchCtrl.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 48,
                    color: isDark ? Colors.amber[300] : Colors.amber[700],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Busca instantáneamente en toda tu base de datos",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (totalMatches == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No se encontraron resultados para '${_searchCtrl.text}'",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Sección Productos
          if ((_activeCategory == 'all' || _activeCategory == 'products') &&
              _productResults.isNotEmpty) ...[
            _buildSectionHeader("📦 PRODUCTOS", _productResults.length, isDark),
            ..._productResults.map((p) => _buildProductTile(p, isDark)),
            const SizedBox(height: 12),
          ],

          // Sección Clientes
          if ((_activeCategory == 'all' || _activeCategory == 'clients') &&
              _clientResults.isNotEmpty) ...[
            _buildSectionHeader("👤 CLIENTES", _clientResults.length, isDark),
            ..._clientResults.map((c) => _buildClientTile(c, isDark)),
            const SizedBox(height: 12),
          ],

          // Sección Cotizaciones
          if ((_activeCategory == 'all' || _activeCategory == 'quotes') &&
              _quoteResults.isNotEmpty) ...[
            _buildSectionHeader(
              "📝 COTIZACIONES",
              _quoteResults.length,
              isDark,
            ),
            ..._quoteResults.map((q) => _buildQuoteTile(q, isDark)),
            const SizedBox(height: 12),
          ],

          // Sección Ventas
          if ((_activeCategory == 'all' || _activeCategory == 'sales') &&
              _saleResults.isNotEmpty) ...[
            _buildSectionHeader("🧾 VENTAS", _saleResults.length, isDark),
            ..._saleResults.map((s) => _buildSaleTile(s, isDark)),
          ],
        ],
      ],
    ),
  );
  }

  Widget _buildCategoryChip(String id, String label, bool isDark) {
    final isSelected = _activeCategory == id;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeCategory = id);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue[700] : Colors.blue[600])
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
            ),
          ),
          Text(
            "$count coincidencias",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p, bool isDark) {
    final double price =
        (p['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
    final int stock = (p['stock_actual'] as int?) ?? 0;
    final int factor = (p['unidades_por_venta'] as int?) ?? 1;
    final int displayStock = factor > 0 ? (stock ~/ factor) : stock;
    final String unit = p['unidad_venta'] ?? 'und';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.inventory_2_rounded,
          size: 18,
          color: isDark ? Colors.blue[300] : Colors.blue[700],
        ),
      ),
      title: Text(
        "${p['producto_nombre'] ?? ''} ${p['nombre_especifico'] ?? ''}".trim(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "Stock: $displayStock $unit · Marca: ${p['marca_nombre'] ?? 'Genérico'}",
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Text(
        "S/ ${price.toStringAsFixed(2)}",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: isDark ? Colors.green[400] : Colors.green[700],
        ),
      ),
      onTap: () {
        Navigator.pop(context); // cerrar sheet
        // Abrir detalle del producto
        final prod = Product(
          id: p['product_id'] as int,
          nombre: p['producto_nombre'] ?? '',
          categoriaId: 0,
          marcaId: 0,
          marcaNombre: p['marca_nombre'],
          imagenUrl: p['p_img'],
        );
        final pres = ProductPresentation(
          id: p['presentation_id'] as int,
          nombreEspecifico: p['nombre_especifico'],
          precioVentaFinal: price,
          stockActual: stock,
          unidadesPorVenta: factor,
          unidadVenta: unit,
          imagenUrl: p['imagen_url'],
        );
        final wrapper = InventoryWrapper(product: prod, presentation: pres);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ProductDetailModal(
            item: wrapper,
            onAddToCart: (qty) {
              Provider.of<CatalogProvider>(context, listen: false)
                  .addToCart(wrapper, qty);
            },
            onAddToList: (qty) {
              Provider.of<CatalogProvider>(context, listen: false)
                  .addToUtilityList(wrapper, qty);
            },
          ),
        );
      },
    );
  }

  Widget _buildClientTile(Map<String, dynamic> c, bool isDark) {
    final double deuda = (c['total_deuda'] as num?)?.toDouble() ?? 0.0;
    final double saldo = (c['saldo_a_favor'] as num?)?.toDouble() ?? 0.0;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDark ? Colors.indigo[800] : Colors.indigo[100],
        child: Text(
          (c['nombre_completo'] != null &&
                  c['nombre_completo'].toString().isNotEmpty)
              ? c['nombre_completo'][0].toUpperCase()
              : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.indigo[900],
          ),
        ),
      ),
      title: Text(
        c['nombre_completo'] ?? 'Sin nombre',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "Telf: ${c['telefono'] ?? 'S/N'} · Confianza: ${c['nivel_confianza'] ?? 'Bueno'}",
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (deuda > 0)
            Text(
              "Debe: S/ ${deuda.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          if (saldo > 0)
            Text(
              "A favor: S/ ${saldo.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          if (deuda <= 0 && saldo <= 0)
            Text(
              "Al día",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        final clientModel = ClientModel(
          id: c['id'] as int,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: c['nombre_completo'] ?? '',
          phone: c['telefono'] ?? '',
          docNumber: c['numero_documento'],
          totalDebt: deuda,
          saldoAFavor: saldo,
          nivelConfianza: c['nivel_confianza'] ?? 'Bueno',
          registeredDate: DateTime.now().toIso8601String(),
          etiquetas: [],
          lastSales: [],
          lastPayments: [],
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(client: clientModel),
          ),
        );
      },
    );
  }

  Widget _buildQuoteTile(Map<String, dynamic> q, bool isDark) {
    final double amount = (q['total_amount'] as num?)?.toDouble() ?? 0.0;
    final int quoteId = q['id'] as int;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.description_outlined,
          size: 18,
          color: isDark ? Colors.orange[300] : Colors.orange[800],
        ),
      ),
      title: Text(
        "Cotización #$quoteId - ${q['client_name'] ?? 'Cliente General'}",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "Estado: ${q['status'] ?? 'Borrador'}",
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Text(
        "S/ ${amount.toStringAsFixed(2)}",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(
              quotationId: quoteId,
              clientName: q['client_name'],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaleTile(Map<String, dynamic> s, bool isDark) {
    final double amount = (s['monto_total'] as num?)?.toDouble() ?? 0.0;
    final int seq = (s['numero_secuencial'] as int?) ?? (s['id'] as int);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.receipt_rounded,
          size: 18,
          color: isDark ? Colors.teal[300] : Colors.teal[700],
        ),
      ),
      title: Text(
        "Venta #$seq - ${s['cliente_nombre'] ?? 'Cliente de Mostrador'}",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "Pago: ${s['estado_pago'] ?? 'completado'} · Fecha: ${s['fecha_venta'] != null ? s['fecha_venta'].toString().substring(0, 10) : ''}",
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Text(
        "S/ ${amount.toStringAsFixed(2)}",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          color: isDark ? Colors.teal[300] : Colors.teal[800],
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}
