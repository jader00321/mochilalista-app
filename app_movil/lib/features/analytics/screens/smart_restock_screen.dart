import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/widgets/product_nomenclature_label.dart';
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/services/purchase_order_generator.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/analytics/screens/smart_restock/smart_restock_item.dart';

export 'package:app_movil/features/analytics/screens/smart_restock/smart_restock_item.dart';

part 'smart_restock/smart_restock_data_and_export.dart';
part 'smart_restock/smart_restock_header_and_kpis.dart';
part 'smart_restock/smart_restock_product_card.dart';
part 'smart_restock/smart_restock_card_controls.dart';
part 'smart_restock/smart_restock_modals_and_summary.dart';

class SmartRestockScreen extends StatefulWidget {
  const SmartRestockScreen({super.key});

  @override
  State<SmartRestockScreen> createState() => _SmartRestockScreenState();
}

abstract class _SmartRestockScreenStateBase extends State<SmartRestockScreen> {
  final InventoryIntelligenceService _biService =
      InventoryIntelligenceService();

  bool _isLoading = true;
  List<SmartRestockItem> _items = [];
  bool _showHelpCard = false;

  // Filtros y Buscador: Por defecto en 'por_pedir' (Urgentes + Preventivos)
  String _currentFilter =
      'por_pedir'; // 'por_pedir', 'urgentes', 'preventivos', 'saludables', 'todos'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _loadData();
  List<SmartRestockItem> get _filteredItems;
  Future<void> _exportOC();
  Widget _buildKpiSummaryBar(bool isDark);
  Widget _buildHelpCard(bool isDark);
  Widget _buildEmptyState();
  Widget _buildSliverList(bool isDark);
  Widget _buildQtyStepper(SmartRestockItem item);
  Widget _buildMetricColumn(
    String label,
    String value,
    Color? valueColor,
    String tooltipText,
  );
  void _showAssignCostModal(SmartRestockItem item);
  Widget _buildSummaryBar(bool isDark);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            'Motor Inteligente de Abastecimiento',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.all(6),
            title: "Reabastecimiento Inteligente",
            description:
                "Calcula a partir de tu velocidad real de ventas y stock vendible cuándo te quedarás sin inventario y cuántas unidades pedir a tus proveedores.",
            tips: [
              InfoTip(
                icon: Icons.speed_rounded,
                text:
                    "ROP (Punto de Reorden): Nivel de stock donde debes reponer mercadería antes de entrar en quiebre.",
              ),
              InfoTip(
                icon: Icons.shield_outlined,
                text:
                    "Stock de Seguridad y Pool Compartido: Contempla reservas para picos de demanda y presentaciones enlazadas al mismo producto padre.",
              ),
              InfoTip(
                icon: Icons.tune_rounded,
                text:
                    "Selecciona ítems con el checkbox, ajusta cantidades sugeridas (+ / -) y genera tu Orden de Compra al instante.",
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            visualDensity: VisualDensity.compact,
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // SECCIÓN RETRÁCTIL: KPIs Superiores y Banner ROP (Se ocultan naturalmente al scrollear hacia abajo)
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKpiSummaryBar(isDark),
                      _buildHelpCard(isDark),
                    ],
                  ),
                ),
                // SECCIÓN PINNED (Fija en el tope): Buscador + Fila de Chips con fondo 100% sólido (REGLA TÉCNICA 3)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySearchAndFilterHeaderDelegate(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    currentFilter: _currentFilter,
                    onFilterSelected: (filter) =>
                        setState(() => _currentFilter = filter),
                    items: _items,
                    isDark: isDark,
                  ),
                ),
                // LISTA DE PRODUCTOS SLIVER
                _buildSliverList(isDark),
              ],
            ),
      bottomNavigationBar: _items.isNotEmpty ? _buildSummaryBar(isDark) : null,
    );
  }
}

class _SmartRestockScreenState extends _SmartRestockScreenStateBase
    with
        _SmartRestockDataAndExportMixin,
        _SmartRestockHeaderAndKpisMixin,
        _SmartRestockProductCardMixin,
        _SmartRestockCardControlsMixin,
        _SmartRestockModalsAndSummaryMixin {}
