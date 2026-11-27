import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'audit_trail/audit_trail_summary_and_help_mixin.dart';
part 'audit_trail/audit_trail_timeline_mixin.dart';

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

abstract class _AuditTrailScreenBase extends State<AuditTrailScreen> {
  final InventoryIntelligenceService _biService =
      InventoryIntelligenceService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  late int _activePresentationId;
  List<Map<String, dynamic>> _presentations = [];
  String _displayedTitle = '';

  int _currentStock = 0;
  double _currentCost = 0.0;
  double _currentPrice = 0.0;
  int _stockInicialBase = 0;
  int _totalEntradas = 0;
  int _totalSalidas = 0;

  bool _activeIsShared = false;
  int _activeFactor = 1;
  String _activeVariantName = '';

  String _selectedFilter = 'todos';

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

  Future<void> _loadAuditTrail([int? presId]);
}

class _AuditTrailScreenState extends _AuditTrailScreenBase
    with _AuditTrailSummaryAndHelpMixin, _AuditTrailTimelineMixin {
  @override
  void initState() {
    super.initState();
    _activePresentationId = widget.presentationId;
    _displayedTitle = widget.productName;
    _loadAuditTrail();
  }

  @override
  Future<void> _loadAuditTrail([int? presId]) async {
    if (presId != null) {
      _activePresentationId = presId;
    }
    setState(() => _isLoading = true);
    try {
      final db = await LocalDatabase.instance.database;

      final prodRows = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [widget.productId],
      );
      final prodData = prodRows.isNotEmpty
          ? prodRows.first
          : <String, dynamic>{};
      final modoStock = prodData['modo_stock']?.toString() ?? 'INDEPENDIENTE';
      final int stockCompartido =
          (prodData['stock_compartido'] as num?)?.toInt() ?? 0;
      final double costoBase =
          (prodData['costo_base'] as num?)?.toDouble() ?? 0.0;

      final ppRows = await db.query(
        'presentaciones_producto',
        where: 'producto_id = ? AND activo = 1',
        orderBy: 'orden ASC, id ASC',
      );

      final List<Map<String, dynamic>> presentationOptions = [];
      final bool hasSharedPres = ppRows.any(
        (r) => (r['usa_stock_compartido'] as int? ?? 0) == 1,
      );
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

        stock = isShared
            ? stockCompartido
            : ((activePres['stock_actual'] as num?)?.toInt() ?? 0);
        cost =
            (activePres['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        price = (activePres['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        presName = (activePres['nombre_especifico'] as String? ?? '').trim();

        final String baseProdName = widget.productName.contains(' • ')
            ? widget.productName.split(' • ').first.trim()
            : widget.productName.trim();
        resolvedTitle = (presName.isNotEmpty && presName != 'Unidad')
            ? '$baseProdName • $presName'
            : baseProdName;
      }

      final data = await _biService.getAuditTrail(
        _activePresentationId,
        widget.productId,
      );

      int entradasBrutas = 0;
      int salidas = 0;
      for (final item in data) {
        if (item['source_type'] == 'STOCK_OP') {
          final int q = (item['cantidad'] as num?)?.toInt() ?? 0;
          if (q > 0) {
            entradasBrutas += q;
          } else {
            salidas += q.abs();
          }
        }
      }

      final int basePreLedger = stock - (entradasBrutas - salidas);

      int dotacionInicialLedger = 0;
      final initialInvItems = data
          .where(
            (i) =>
                i['source_type'] == 'STOCK_OP' &&
                i['accion'] == 'INVENTARIO_INICIAL',
          )
          .toList();

      if (initialInvItems.isNotEmpty) {
        dotacionInicialLedger =
            (initialInvItems.last['cantidad'] as num?)?.toInt() ?? 0;
      } else if (basePreLedger == 0) {
        final positiveOps = data
            .where(
              (i) =>
                  i['source_type'] == 'STOCK_OP' &&
                  ((i['cantidad'] as num?)?.toInt() ?? 0) > 0,
            )
            .toList();
        if (positiveOps.isNotEmpty) {
          dotacionInicialLedger =
              (positiveOps.last['cantidad'] as num?)?.toInt() ?? 0;
        }
      }

      final int stockInicialBase = basePreLedger + dotacionInicialLedger;
      int entradasPosteriores = entradasBrutas - dotacionInicialLedger;
      if (entradasPosteriores < 0) entradasPosteriores = 0;

      if (mounted) {
        setState(() {
          _presentations = presentationOptions;
          _displayedTitle = resolvedTitle;
          _history = data;
          _currentStock = stock;
          _currentCost = cost;
          _currentPrice = price;
          _stockInicialBase = stockInicialBase;
          _totalEntradas = entradasPosteriores;
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
        AppFeedbackHelper.showSnackBar(
          context,
          'Error al cargar historial: $e',
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_selectedFilter == 'stock') {
      return _history.where((i) => i['source_type'] == 'STOCK_OP').toList();
    }
    if (_selectedFilter == 'precios') {
      return _history
          .where(
            (i) =>
                i['source_type'] == 'META_OP' &&
                (i['accion'] == 'precio_venta_final' ||
                    i['accion'] == 'costo_unitario_calculado'),
          )
          .toList();
    }
    if (_selectedFilter == 'descuentos') {
      return _history
          .where(
            (i) => i['source_type'] == 'META_OP' && i['accion'] == 'descuento',
          )
          .toList();
    }
    if (_selectedFilter == 'ficha') {
      return _history
          .where(
            (i) =>
                i['source_type'] == 'META_OP' &&
                i['accion'] != 'precio_venta_final' &&
                i['accion'] != 'costo_unitario_calculado' &&
                i['accion'] != 'descuento',
          )
          .toList();
    }
    return _history;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Trazabilidad",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          InfoTooltipButton(
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.all(6),
            title: "Trazabilidad de Stock (Kardex)",
            description:
                "Bitácora cronológica auditable de cada entrada y salida de inventario: ingresos por factura, ventas directas y ajustes manuales.",
            tips: [
              InfoTip(
                icon: Icons.timeline_rounded,
                text:
                    "Cada registro detalla fecha, tipo de operación, cantidad operada y saldo resultante.",
              ),
              InfoTip(
                icon: Icons.receipt_outlined,
                text:
                    "Las compras vinculadas muestran la factura de origen, proveedor y variaciones de costo.",
              ),
              InfoTip(
                icon: Icons.shield_outlined,
                text:
                    "Filtra por tipo de evento para auditar diferencias de stock compartido o controlar rotación.",
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
                SliverToBoxAdapter(child: _buildSummaryCard(isDark)),
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
                        child: Text(
                          "No hay registros que coincidan con este filtro.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = _filteredHistory[index];
                        return _buildTimelineItem(
                          item,
                          isDark,
                          index == _filteredHistory.length - 1,
                        );
                      }, childCount: _filteredHistory.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildEventFilterChips(bool isDark) {
    final int stockOpsCount = _history
        .where((i) => i['source_type'] == 'STOCK_OP')
        .length;
    final int priceCostCount = _history
        .where(
          (i) =>
              i['source_type'] == 'META_OP' &&
              (i['accion'] == 'precio_venta_final' ||
                  i['accion'] == 'costo_unitario_calculado'),
        )
        .length;
    final int discountsCount = _history
        .where(
          (i) => i['source_type'] == 'META_OP' && i['accion'] == 'descuento',
        )
        .length;
    final int fichaCount = _history
        .where(
          (i) =>
              i['source_type'] == 'META_OP' &&
              i['accion'] != 'precio_venta_final' &&
              i['accion'] != 'costo_unitario_calculado' &&
              i['accion'] != 'descuento',
        )
        .length;

    return SizedBox(
      height: 38,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.02, 0.98, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildFilterChip(
              "Todos (${_history.length})",
              Icons.list_alt_rounded,
              'todos',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              "Movimientos ($stockOpsCount)",
              Icons.inventory_2_outlined,
              'stock',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              "Precios y Costos ($priceCostCount)",
              Icons.attach_money_rounded,
              'precios',
              isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              "Descuentos ($discountsCount)",
              Icons.local_offer_outlined,
              'descuentos',
              isDark,
              activeColor: const Color(0xFFE11D48),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              "Ficha Técnica ($fichaCount)",
              Icons.edit_note_rounded,
              'ficha',
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    String filterKey,
    bool isDark, {
    Color? activeColor,
  }) {
    final bool isSelected = _selectedFilter == filterKey;
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
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      selectedColor: activeColor ?? Colors.purpleAccent,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white12 : Colors.grey[300]!),
        ),
      ),
      onSelected: (_) {
        setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
