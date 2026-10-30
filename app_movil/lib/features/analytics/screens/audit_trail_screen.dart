import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class AuditTrailScreen extends StatefulWidget {
  final int presentationId;
  final int productId;
  final String productName;

  const AuditTrailScreen({
    super.key,
    required this.presentationId,
    required this.productId,
    required this.productName,
  });

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final InventoryIntelligenceService _biService = InventoryIntelligenceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  
  late int _activePresentationId;
  List<Map<String, dynamic>> _presentations = [];
  String _displayedTitle = '';

  int _currentStock = 0;
  double _currentCost = 0.0;
  double _currentPrice = 0.0;
  int _totalEntradas = 0;
  int _totalSalidas = 0;

  bool _activeIsShared = false;
  int _activeFactor = 1;
  String _activeVariantName = '';

  String get _variantEquivString {
    if (!_activeIsShared || _activeFactor <= 1) return "";
    final equiv = _currentStock ~/ _activeFactor;
    String name = _activeVariantName.isEmpty ? 'Packs' : _activeVariantName;
    if (name.toLowerCase() == 'par' && equiv != 1) {
      name = 'Pares';
    } else if (name.toLowerCase() == 'caja' && equiv != 1) {
      name = 'Cajas';
    }
    return "$equiv $name x$_activeFactor";
  }

  // Filtro de eventos
  String _selectedFilter = 'todos'; // 'todos', 'stock', 'precios', 'ficha'

  @override
  void initState() {
    super.initState();
    _activePresentationId = widget.presentationId;
    _displayedTitle = widget.productName;
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail([int? presId]) async {
    if (presId != null) {
      _activePresentationId = presId;
    }
    setState(() => _isLoading = true);
    try {
      final db = await LocalDatabase.instance.database;
      
      // Consultar información del producto (modo_stock, stock_compartido, costo_base)
      final prodRows = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [widget.productId],
      );
      final prodData = prodRows.isNotEmpty ? prodRows.first : <String, dynamic>{};
      final modoStock = prodData['modo_stock']?.toString() ?? 'INDEPENDIENTE';
      final int stockCompartido = (prodData['stock_compartido'] as num?)?.toInt() ?? 0;
      final double costoBase = (prodData['costo_base'] as num?)?.toDouble() ?? 0.0;

      // Consultar todas las variantes activas del producto para el selector
      final ppRows = await db.query(
        'presentaciones_producto',
        where: 'producto_id = ? AND activo = 1',
        orderBy: 'orden ASC, id ASC',
      );

      final List<Map<String, dynamic>> presentationOptions = [];
      bool hasSharedPres = ppRows.any((r) => (r['usa_stock_compartido'] as int? ?? 0) == 1);
      if (hasSharedPres || modoStock == 'COMPARTIDO' || modoStock == 'MIXTO') {
        presentationOptions.add({
          'id': -1,
          'nombre_especifico': 'Pool Compartido',
          'usa_stock_compartido': 1,
          'stock_actual': stockCompartido,
          'costo_unitario_calculado': costoBase,
          'precio_venta_final': 0.0,
        });
      }
      presentationOptions.addAll(ppRows);

      int stock = 0;
      double cost = 0.0;
      double price = 0.0;
      String presName = '';
      String resolvedTitle = '';
      bool isShared = false;
      int factor = 1;

      if (_activePresentationId == -1) {
        stock = stockCompartido;
        cost = costoBase;
        price = 0.0;
        presName = 'Pool Compartido';
        resolvedTitle = '${widget.productName} • Pool Compartido';
        isShared = true;
        factor = 1;
      } else {
        Map<String, dynamic> activePres = {};
        if (ppRows.isNotEmpty) {
          activePres = ppRows.firstWhere(
            (r) => (r['id'] as num).toInt() == _activePresentationId,
            orElse: () => ppRows.first,
          );
          _activePresentationId = (activePres['id'] as num).toInt();
        } else {
          final fallback = await db.query(
            'presentaciones_producto',
            where: 'id = ?',
            whereArgs: [_activePresentationId],
          );
          if (fallback.isNotEmpty) activePres = fallback.first;
        }

        isShared = (activePres['usa_stock_compartido'] as num?)?.toInt() == 1;
        factor = (activePres['unidades_por_venta'] as num?)?.toInt() ?? 1;
        if (factor <= 0) factor = 1;

        // Si usa stock compartido, la escala base es el stock del pool
        stock = isShared ? stockCompartido : ((activePres['stock_actual'] as num?)?.toInt() ?? 0);
        cost = (activePres['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        price = (activePres['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        presName = (activePres['nombre_especifico'] as String? ?? '').trim();

        String baseProdName = widget.productName.contains(' • ')
            ? widget.productName.split(' • ').first.trim()
            : widget.productName.trim();
        resolvedTitle = (presName.isNotEmpty && presName != 'Unidad')
            ? '$baseProdName • $presName'
            : baseProdName;
      }

      // Obtener el Audit Trail exacto para la variante activa o pool consolidado (-1)
      final data = await _biService.getAuditTrail(_activePresentationId, widget.productId);

      int entradas = 0;
      int salidas = 0;
      for (var item in data) {
        if (item['source_type'] == 'STOCK_OP') {
          int q = (item['cantidad'] as num?)?.toInt() ?? 0;
          if (q > 0) {
            entradas += q;
          } else {
            salidas += q.abs();
          }
        }
      }

      if (mounted) {
        setState(() {
          _presentations = presentationOptions;
          _displayedTitle = resolvedTitle;
          _history = data;
          _currentStock = stock;
          _currentCost = cost;
          _currentPrice = price;
          _totalEntradas = entradas;
          _totalSalidas = salidas;
          _activeIsShared = isShared;
          _activeFactor = factor;
          _activeVariantName = presName;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_selectedFilter == 'stock') {
      return _history.where((i) => i['source_type'] == 'STOCK_OP').toList();
    } else if (_selectedFilter == 'precios') {
      return _history.where((i) => i['source_type'] == 'META_OP' && 
          (i['accion'] == 'precio_venta_final' || i['accion'] == 'costo_unitario_calculado')).toList();
    } else if (_selectedFilter == 'descuentos') {
      return _history.where((i) => i['source_type'] == 'META_OP' && i['accion'] == 'descuento').toList();
    } else if (_selectedFilter == 'ficha') {
      return _history.where((i) => i['source_type'] == 'META_OP' && 
          i['accion'] != 'precio_venta_final' && 
          i['accion'] != 'costo_unitario_calculado' && 
          i['accion'] != 'descuento').toList();
    }
    return _history;
  }

  String _formatDateSpanish(DateTime date) {
    const months = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'set.', 'oct.', 'nov.', 'dic.'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$day $month $year • $hour:$minute";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Trazabilidad", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          InfoTooltipButton(
            title: "Trazabilidad de Stock (Kardex)",
            description:
                "Historial cronológico de auditoría para cada movimiento de stock: compras por factura, ventas directas y ajustes de inventario.",
            tips: [
              InfoTip(
                icon: Icons.timeline_rounded,
                text: "Cada evento muestra la fecha, tipo de movimiento, cantidad operada y saldos resultantes.",
              ),
              InfoTip(
                icon: Icons.receipt_outlined,
                text: "Las compras registradas indican la factura de procedencia y su proveedor.",
              ),
              InfoTip(
                icon: Icons.shield_outlined,
                text: "Permite auditar diferencias de existencias y controlar la rotación exacta del producto.",
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSummaryCard(isDark),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildEventFilterChips(isDark),
                  ),
                ),
                if (_filteredHistory.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("No hay registros que coincidan con este filtro.", style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _filteredHistory[index];
                          return _buildTimelineItem(item, isDark, index == _filteredHistory.length - 1);
                        },
                        childCount: _filteredHistory.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  // =========================================================================
  // CABECERA 360 DEL PRODUCTO (STOCK, COSTO, PRECIO, MARGEN Y BALANCE ENTRADAS/SALIDAS)
  // =========================================================================
  Widget _buildSummaryCard(bool isDark) {
    double marginPct = _currentPrice > 0 ? ((_currentPrice - _currentCost) / _currentPrice) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] 
              : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayedTitle.isNotEmpty ? _displayedTitle : widget.productName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (_activeIsShared && _activeFactor > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        "Stock Pool: $_currentStock und. base ($_variantEquivString)",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: "Información de Trazabilidad",
                onPressed: _showTraceabilityHelpModal,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          if (_presentations.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presentations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final p = _presentations[idx];
                  final pId = (p['id'] as num).toInt();
                  final pLabel = (p['nombre_especifico']?.toString().trim().isNotEmpty == true)
                      ? p['nombre_especifico'].toString().trim()
                      : 'Unidad';
                  final isSelected = pId == _activePresentationId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (!isSelected) {
                        _loadAuditTrail(pId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white24,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (p['usa_stock_compartido'] == 1 || pId == -1)
                                ? Icons.hub_outlined
                                : Icons.inventory_2_outlined,
                            size: 11,
                            color: isSelected ? const Color(0xFF312E81) : Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF312E81) : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Métricas clave: Stock, Costo, Precio y Margen
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Stock Actual",
                    value: (_activeIsShared && _activeFactor > 1)
                        ? "$_currentStock und. base\n($_variantEquivString)"
                        : "$_currentStock und",
                    color: Colors.white,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Costo Est.",
                    value: AppCurrency.format(_currentCost),
                    color: Colors.amberAccent,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Precio Venta",
                    value: AppCurrency.format(_currentPrice),
                    color: Colors.lightGreenAccent,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Margen",
                    value: "${marginPct.toStringAsFixed(1)}%",
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Resumen de Entradas vs Salidas en 1 sola fila equilibrada (Captura 4)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_downward, size: 13, color: Colors.greenAccent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          "Entradas: +$_totalEntradas und. base",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_upward, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          "Salidas: -$_totalSalidas und. base",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Conciliación de Stock Inicial y Saldo Auditoría en 2 líneas adaptables y responsivas
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 13, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Stock Inicial Base: ${_currentStock - (_totalEntradas - _totalSalidas)} und. base",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, size: 13, color: Colors.cyanAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Saldo Auditoría: ${_currentStock - (_totalEntradas - _totalSalidas)} + $_totalEntradas - $_totalSalidas = $_currentStock und. base${_activeIsShared && _activeFactor > 1 ? ' ($_variantEquivString)' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // CHIPS DE FILTRO DE EVENTOS (MANDATORY RULE 1: CERO UNBOUNDED HEIGHT)
  // =========================================================================
  Widget _buildEventFilterChips(bool isDark) {
    int stockOpsCount = _history.where((i) => i['source_type'] == 'STOCK_OP').length;
    int priceCostCount = _history.where((i) => i['source_type'] == 'META_OP' && 
        (i['accion'] == 'precio_venta_final' || i['accion'] == 'costo_unitario_calculado')).length;
    int discountsCount = _history.where((i) => i['source_type'] == 'META_OP' && i['accion'] == 'descuento').length;
    int fichaCount = _history.where((i) => i['source_type'] == 'META_OP' && 
        i['accion'] != 'precio_venta_final' && 
        i['accion'] != 'costo_unitario_calculado' && 
        i['accion'] != 'descuento').length;

    return SizedBox(
      height: 38,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.02, 0.98, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildFilterChip("Todos (${_history.length})", Icons.list_alt_rounded, 'todos', isDark),
            const SizedBox(width: 8),
            _buildFilterChip("Movimientos ($stockOpsCount)", Icons.inventory_2_outlined, 'stock', isDark),
            const SizedBox(width: 8),
            _buildFilterChip("Precios y Costos ($priceCostCount)", Icons.attach_money_rounded, 'precios', isDark),
            const SizedBox(width: 8),
            _buildFilterChip(
              "Descuentos ($discountsCount)", 
              Icons.local_offer_outlined,
              'descuentos', 
              isDark,
              activeColor: const Color(0xFFE11D48),
            ),
            const SizedBox(width: 8),
            _buildFilterChip("Ficha Técnica ($fichaCount)", Icons.edit_note_rounded, 'ficha', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, String filterKey, bool isDark, {Color? activeColor}) {
    bool isSelected = _selectedFilter == filterKey;
    return FilterChip(
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 13,
        color: isSelected ? Colors.white : (activeColor ?? Colors.purpleAccent),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      selectedColor: activeColor ?? Colors.purpleAccent,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey[300]!)),
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = filterKey);
      },
    );
  }

  // =========================================================================
  // MODAL DIDÁCTICO BOTÓN (?) CON INTERACTIVESHEETWRAPPER (MANDATORY RULE 4)
  // =========================================================================
  void _showTraceabilityHelpModal() {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Trazabilidad de Stock (Kardex)",
        icon: Icons.timeline_rounded,
        iconColor: Colors.purpleAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "La ventana de Trazabilidad es tu auditoría digital en tiempo real: registra cada evento que afecta al producto a lo largo del tiempo.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildHelpRow(
                icon: Icons.shopping_cart_checkout,
                color: Colors.redAccent,
                title: "Ventas en Caja",
                description: "Disminuyen el inventario físico y registran la salida de existencias.",
              ),
              _buildHelpRow(
                icon: Icons.local_shipping,
                color: Colors.green,
                title: "Ingreso por Factura",
                description: "Incrementan el stock tras procesar compras con el escáner de facturas.",
              ),
              _buildHelpRow(
                icon: Icons.tune,
                color: Colors.blueAccent,
                title: "Ajustes Manuales",
                description: "Correcciones directas por inventario físico, mermas o inventario inicial.",
              ),
              _buildHelpRow(
                icon: Icons.price_change,
                color: Colors.purpleAccent,
                title: "Cambios de Precio y Costo",
                description: "Histórico de actualizaciones de costos de proveedor y precios de venta al público.",
              ),
              _buildHelpRow(
                icon: Icons.local_offer_rounded,
                color: const Color(0xFFE11D48),
                title: "Descuentos y Promociones",
                description: "Histórico de ofertas activadas, cambios de porcentaje y retorno a precio normal.",
              ),
              _buildHelpRow(
                icon: Icons.label,
                color: Colors.orangeAccent,
                title: "Ediciones de Ficha",
                description: "Cambios en marcas, categorías, nombres o estado de visibilidad del producto.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ITEM DE LÍNEA DE TIEMPO (SIN EMOJIS DUPLICADOS, FLOATS FORMATEADOS, NOMBRES REALES)
  // =========================================================================
  Widget _buildTimelineItem(Map<String, dynamic> item, bool isDark, bool isLast) {
    bool isStockOp = item['source_type'] == 'STOCK_OP';
    String rawAction = item['accion']?.toString() ?? 'Desconocido';
    DateTime date = DateTime.tryParse(item['fecha'].toString()) ?? DateTime.now();
    String formattedDate = _formatDateSpanish(date);
    String formattedTime = _formatTime(date);

    IconData icon;
    Color color;
    String displayAction;

    if (isStockOp) {
      int qty = (item['cantidad'] as num?)?.toInt() ?? 0;
      if (rawAction == 'VENTA') {
        icon = Icons.shopping_cart_checkout;
        color = Colors.redAccent;
        displayAction = 'Venta en Caja';
      } else if (rawAction == 'INVENTARIO_INICIAL') {
        icon = Icons.flag;
        color = Colors.blue;
        displayAction = 'Punto de Partida';
      } else if (rawAction == 'COMPRA_LOTE' || rawAction == 'COMPRA_FACTURA') {
        icon = Icons.local_shipping;
        color = Colors.green;
        displayAction = 'Ingreso por Factura';
      } else if (rawAction == 'AJUSTE_INVENTARIO' || rawAction == 'AJUSTE_MANUAL' || rawAction == 'AJUSTE') {
        if (qty > 0) {
          icon = Icons.add_circle_outline;
          color = Colors.green;
          displayAction = 'Ajuste Manual (+)';
        } else {
          icon = Icons.remove_circle_outline;
          color = Colors.redAccent;
          displayAction = 'Ajuste Manual (-)';
        }
      } else {
        icon = Icons.swap_horiz;
        color = Colors.grey;
        displayAction = rawAction.replaceAll('_', ' ').toLowerCase();
        displayAction = displayAction.isNotEmpty ? displayAction[0].toUpperCase() + displayAction.substring(1) : displayAction;
      }
    } else {
      if (rawAction == 'precio_venta_final') {
        icon = Icons.price_change;
        color = Colors.purpleAccent;
        displayAction = 'Precio de Venta Actualizado';
      } else if (rawAction == 'costo_unitario_calculado') {
        icon = Icons.analytics;
        color = Colors.purpleAccent;
        displayAction = 'Costo Interno Ajustado';
      } else if (rawAction == 'descuento') {
        icon = Icons.local_offer_rounded;
        color = const Color(0xFFE11D48);
        String valNuevo = item['valor_nuevo']?.toString() ?? '';
        String valAnt = item['valor_anterior']?.toString() ?? '';
        if (valNuevo.startsWith('Oferta finalizada') || valNuevo.contains('Desactivado')) {
          displayAction = 'Descuento Retirado';
        } else if (valAnt == 'Sin descuento' || valAnt.isEmpty || valAnt == 'null') {
          displayAction = 'Descuento Aplicado';
        } else {
          displayAction = 'Descuento Modificado';
        }
      } else if (rawAction == 'estado') {
        icon = Icons.visibility;
        color = Colors.orangeAccent;
        displayAction = 'Visibilidad Cambiada';
      } else if (rawAction == 'marca_id' || rawAction == 'categoria_id') {
        icon = Icons.label;
        color = Colors.blueAccent;
        displayAction = rawAction == 'categoria_id' ? 'Categoría Modificada' : 'Marca Modificada';
      } else if (rawAction == 'modo_stock') {
        icon = Icons.hub;
        color = Colors.teal;
        displayAction = 'Estrategia de Stock Modificada';
      } else {
        icon = Icons.build_circle_outlined;
        color = Colors.purpleAccent;
        displayAction = rawAction.replaceAll('_', ' ').toLowerCase();
        displayAction = displayAction.isNotEmpty ? displayAction[0].toUpperCase() + displayAction.substring(1) : displayAction;
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDark ? Colors.white12 : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayAction, 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                          ),
                        ),
                        Text(formattedTime, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isStockOp) ...[
                      Row(
                        children: [
                          Icon(Icons.tag, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.bold,
                                  color: ((item['cantidad'] as num?)?.toInt() ?? 0) > 0 ? Colors.green : Colors.redAccent,
                                ),
                                children: [
                                  TextSpan(text: "Cantidad: ${((item['cantidad'] as num?)?.toInt() ?? 0) > 0 ? '+' : ''}${item['cantidad']} und. base"),
                                  if (item['presentacion_nombre'] != null && (item['presentacion_nombre'] as String).trim().isNotEmpty && item['presentacion_nombre'] != 'Unidad')
                                    TextSpan(
                                      text: " (${item['presentacion_nombre']})",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item['es_presentacion_hermana'] == 1) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hub_outlined, size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  "Impacto en Pool Común vía presentación hermana: ${item['presentacion_nombre'] ?? 'Variante'} (Factor x${item['unidades_por_venta'] ?? 1})",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      _buildMetaOpContent(item, isDark),
                    ],
                    const SizedBox(height: 8),
                    Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RENDERIZADO ELEGANTE DE METADATOS (MANDATORY RULE 4: NOMBRES Y APP_CURRENCY)
  // =========================================================================
  Widget _buildMetaOpContent(Map<String, dynamic> item, bool isDark) {
    if (item['accion'] == 'modo_stock') {
      String oldVal = item['valor_anterior_label'] ?? item['valor_anterior']?.toString() ?? 'INDEPENDIENTE';
      String newVal = item['valor_nuevo_label'] ?? item['valor_nuevo']?.toString() ?? 'COMPARTIDO';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 15, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.teal[100] : Colors.teal[900]),
                  children: [
                    const TextSpan(text: "Estrategia: "),
                    TextSpan(text: oldVal, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    const TextSpan(text: " ➔ "),
                    TextSpan(text: newVal, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item['accion'] == 'descuento') {
      String oldVal = item['valor_anterior_label'] ?? item['valor_anterior']?.toString() ?? 'Sin descuento';
      String newVal = item['valor_nuevo_label'] ?? item['valor_nuevo']?.toString() ?? '';
      bool isRemoved = newVal.startsWith('Oferta finalizada') || newVal.contains('Desactivado');
      bool isNew = oldVal == 'Sin descuento' || oldVal.isEmpty || oldVal == 'null';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.25)),
        ),
        child: isNew
            ? Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 15, color: Color(0xFFE11D48)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newVal,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                    ),
                  ),
                ],
              )
            : isRemoved
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.remove_circle_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              oldVal,
                              style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newVal,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          oldVal,
                          style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          newVal,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                      ),
                    ],
                  ),
      );
    }

    String oldLabel = item['valor_anterior_label'] ?? item['valor_anterior']?.toString() ?? 'Inicial';
    String newLabel = item['valor_nuevo_label'] ?? item['valor_nuevo']?.toString() ?? 'Sin asignar';

    if (oldLabel == 'null' || oldLabel.isEmpty || oldLabel == '0') {
      oldLabel = 'Inicial';
    }
    if (newLabel == 'null' || newLabel.isEmpty || newLabel == '0') {
      newLabel = 'Sin asignar';
    }

    bool isInitialAssignment = oldLabel == 'Inicial' || oldLabel == 'Sin categoría' || oldLabel == 'Sin marca';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: isInitialAssignment
          ? Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Asignado: $newLabel",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    oldLabel, 
                    style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey),
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    newLabel, 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
    );
  }
}
