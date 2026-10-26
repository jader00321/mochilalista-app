import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/widgets/product_nomenclature_label.dart';
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/services/purchase_order_generator.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class SmartRestockItem {
  final int presentationId;
  final int productId;
  final String productName;
  final String brandName;
  final String presentationName;
  final int currentStock;
  double cost;
  final double velocityPerDay;
  final String velocityDisplay;
  final int safetyStock;
  final int rop;
  final int suggestedQty;
  int orderQty;
  bool isSelected;
  final double daysToStockout;
  final String stockoutDate;
  final String status; // 'agotado', 'critico', 'preventivo', 'saludable'
  final Color statusColor;
  final String statusText;
  bool hasZeroCost;

  SmartRestockItem({
    required this.presentationId,
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.presentationName,
    required this.currentStock,
    required this.cost,
    required this.velocityPerDay,
    required this.velocityDisplay,
    required this.safetyStock,
    required this.rop,
    required this.suggestedQty,
    required this.orderQty,
    this.isSelected = false,
    required this.daysToStockout,
    required this.stockoutDate,
    required this.status,
    required this.statusColor,
    required this.statusText,
    required this.hasZeroCost,
  });
}

class SmartRestockScreen extends StatefulWidget {
  const SmartRestockScreen({super.key});

  @override
  State<SmartRestockScreen> createState() => _SmartRestockScreenState();
}

class _SmartRestockScreenState extends State<SmartRestockScreen> {
  final InventoryIntelligenceService _biService = InventoryIntelligenceService();
  
  bool _isLoading = true;
  List<SmartRestockItem> _items = [];
  bool _showHelpCard = false;

  // Filtros y Buscador: Por defecto en 'por_pedir' (Urgentes + Preventivos)
  String _currentFilter = 'por_pedir'; // 'por_pedir', 'urgentes', 'preventivos', 'saludables', 'todos'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = await LocalDatabase.instance.database;
      
      final products = await db.rawQuery('''
        SELECT pp.id as presentation_id, p.id as product_id, p.nombre, IFNULL(m.nombre, 'Sin Marca') as marca_nombre, 
               pp.nombre_especifico, pp.stock_actual, pp.costo_unitario_calculado, IFNULL(pp.stock_alerta, 5) as stock_alerta
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [auth.activeBusinessId]);

      List<SmartRestockItem> results = [];
      
      for (var row in products) {
        int presId = row['presentation_id'] as int;
        int currentStock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        int configuredAlert = (row['stock_alerta'] as num?)?.toInt() ?? 5;
        double cost = (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;

        final biData = await _biService.calculateReorderPoint(
          presId, 
          currentStock, 
          configuredAlertStock: configuredAlert,
        );
        
        int rop = (biData['rop'] as num).toInt();
        double vel = (biData['velocity_per_day'] as num).toDouble();
        String velocityDisplay = biData['velocity_display'] as String? ?? "${vel.toStringAsFixed(1)}/d";
        double daysToStockout = (biData['days_to_stockout'] as num).toDouble();
        String stockoutDate = biData['stockout_date'] as String? ?? "";
        int suggestedQty = (biData['suggested_order_qty'] as num).toInt();
        String status = biData['status'] as String? ?? "saludable";

        Color statusColor;
        String statusText;

        if (status == 'agotado') {
          statusColor = Colors.red[900]!;
          statusText = '🚨 Agotado';
        } else if (status == 'critico') {
          statusColor = Colors.redAccent;
          statusText = '🔴 Stock Crítico'; // Texto compactado para dar ancho al nombre del producto
        } else if (status == 'preventivo') {
          statusColor = Colors.orangeAccent;
          statusText = '🟠 Preventivo';
        } else {
          statusColor = Colors.green;
          statusText = '🟢 Saludable';
        }

        // Selección por defecto: todos los ítems de "Por Pedir" (requieren reposición o suggestedQty > 0)
        bool isRestockItem = status != 'saludable' || suggestedQty > 0;
        int initialOrderQty = suggestedQty > 0 ? suggestedQty : math.max(1, rop);

        results.add(SmartRestockItem(
          presentationId: presId,
          productId: row['product_id'] as int,
          productName: row['nombre'] as String,
          brandName: row['marca_nombre'] as String,
          presentationName: row['nombre_especifico'] as String? ?? 'Unidad',
          currentStock: currentStock,
          cost: cost,
          velocityPerDay: vel,
          velocityDisplay: velocityDisplay,
          safetyStock: (biData['safety_stock'] as num).toInt(),
          rop: rop,
          suggestedQty: suggestedQty,
          orderQty: initialOrderQty,
          isSelected: isRestockItem,
          daysToStockout: daysToStockout,
          stockoutDate: stockoutDate,
          status: status,
          statusColor: statusColor,
          statusText: statusText,
          hasZeroCost: cost <= 0,
        ));
      }
      
      // Ordenar por urgencia: Agotados primero, luego Críticos, luego Preventivos, luego Saludables
      results.sort((a, b) {
        int rank(String s) {
          switch (s) {
            case 'agotado': return 0;
            case 'critico': return 1;
            case 'preventivo': return 2;
            default: return 3;
          }
        }
        int rankDiff = rank(a.status).compareTo(rank(b.status));
        if (rankDiff != 0) return rankDiff;
        // Si tienen el mismo rango, mayor déficit respecto a ROP primero
        int deficitA = a.rop - a.currentStock;
        int deficitB = b.rop - b.currentStock;
        return deficitB.compareTo(deficitA);
      });

      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar inventario: $e')));
      }
    }
  }

  // Filtrado reactivo en memoria
  List<SmartRestockItem> get _filteredItems {
    return _items.where((item) {
      // Filtro de estado
      if (_currentFilter == 'por_pedir') {
        if (item.status == 'saludable' && item.suggestedQty <= 0) {
          return false;
        }
      } else if (_currentFilter == 'urgentes') {
        if (item.status != 'agotado' && item.status != 'critico') return false;
      } else if (_currentFilter == 'preventivos') {
        if (item.status != 'preventivo') return false;
      } else if (_currentFilter == 'saludables') {
        if (item.status != 'saludable') return false;
      }

      // Buscador
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.productName.toLowerCase().contains(q);
        final matchBrand = item.brandName.toLowerCase().contains(q);
        final matchPres = item.presentationName.toLowerCase().contains(q);
        if (!matchName && !matchBrand && !matchPres) return false;
      }

      return true;
    }).toList();
  }

  // =========================================================================
  // PERSISTENCIA EN VIVO: MODAL ASIGNAR COSTO (ETIQUETA SUPERIOR FIJA LIMPIA)
  // =========================================================================
  void _showAssignCostModal(SmartRestockItem item) {
    final costController = TextEditingController(text: item.cost > 0 ? item.cost.toStringAsFixed(2) : '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Asignar Costo de Compra",
        icon: Icons.payments_outlined,
        iconColor: Colors.blueAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${item.productName} (${item.presentationName})",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                "Ingresa el costo unitario de compra a tu proveedor para calcular la inversión requerida y proteger tu margen.",
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              Text(
                "Costo Unitario de Compra (Proveedor)",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: costController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: "S/ ",
                  hintText: "0.00",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: "Ejemplo: 3.50 — Se actualizará en todo el inventario",
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Guardar Costo en Inventario"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final text = costController.text.trim().replaceAll(',', '.');
                    final newCost = double.tryParse(text);
                    if (newCost == null || newCost < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Por favor ingresa un monto válido mayor a 0.")),
                      );
                      return;
                    }

                    try {
                      final db = await LocalDatabase.instance.database;
                      await db.update(
                        'presentaciones_producto',
                        {'costo_unitario_calculado': newCost},
                        where: 'id = ?',
                        whereArgs: [item.presentationId],
                      );

                      // Registrar cambio en product_history
                      await db.insert('product_history', {
                        'entidad_tipo': 'PRESENTACION',
                        'entidad_id': item.presentationId,
                        'campo_modificado': 'costo_unitario_calculado',
                        'valor_anterior': item.cost.toString(),
                        'valor_nuevo': newCost.toString(),
                        'fecha_cambio': DateTime.now().toIso8601String(),
                      });

                      if (!mounted) return;
                      setState(() {
                        item.cost = newCost;
                        item.hasZeroCost = false;
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Costo actualizado a ${AppCurrency.format(newCost)}."), backgroundColor: Colors.green),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error al guardar costo: $e"), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // EXPORTACIÓN A PDF DE LA ORDEN DE COMPRA SELECCIONADA
  // =========================================================================
  Future<void> _exportOC() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final selectedItems = _items.where((i) => i.isSelected).toList();
      if (selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un producto para exportar la Orden de Compra.')),
        );
        return;
      }
      final file = await PurchaseOrderGenerator.exportToPdf(selectedItems, auth.businessName);
      if (!mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Orden de Compra Sugerida - ${auth.businessName}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Motor Inteligente de Abastecimiento', 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            title: "Reabastecimiento Inteligente",
            description:
                "Calcula en base a tu velocidad de ventas cuándo te quedarás sin stock y cuántas unidades debes pedir a tus proveedores.",
            tips: [
              InfoTip(
                icon: Icons.speed_rounded,
                text: "ROP (Punto de Reorden): Nivel de stock donde debes solicitar producto antes de que se agote.",
              ),
              InfoTip(
                icon: Icons.shield_outlined,
                text: "Stock de Seguridad: Cantidad de reserva para absorber picos inesperados de demanda.",
              ),
              InfoTip(
                icon: Icons.tune,
                text: "Marca productos con el checkbox y ajusta cantidades con (+ / -) antes de Exportar OC.",
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty 
              ? _buildEmptyState()
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                        onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                        currentFilter: _currentFilter,
                        onFilterSelected: (filter) => setState(() => _currentFilter = filter),
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

  // =========================================================================
  // BARRA DE KPIS SUPERIORES DE ABASTECIMIENTO
  // =========================================================================
  Widget _buildKpiSummaryBar(bool isDark) {
    final reabastecerCount = _items.where((i) => i.status != 'saludable' || i.suggestedQty > 0).length;
    final agotadosCount = _items.where((i) => i.currentStock == 0).length;
    final selectedItems = _items.where((i) => i.isSelected).toList();
    final totalInversion = selectedItems.fold(0.0, (sum, i) => sum + (i.orderQty * i.cost));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: _buildKpiCard(
              title: "Por Pedir",
              value: "$reabastecerCount",
              color: reabastecerCount > 0 ? Colors.redAccent : Colors.green,
              icon: Icons.assignment_late_outlined,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: "Agotados",
              value: "$agotadosCount",
              color: agotadosCount > 0 ? Colors.red[900]! : Colors.green,
              icon: Icons.warning_amber_rounded,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKpiCard(
              title: "Inversión OC",
              value: AppCurrency.format(totalInversion),
              color: Colors.blueAccent,
              icon: Icons.shopping_cart_checkout,
              isDark: isDark,
              isCompactAmount: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isCompactAmount = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isCompactAmount ? 13 : 15, 
                fontWeight: FontWeight.bold, 
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        color: isDark ? const Color(0xFF1E293B) : Colors.blue[50],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue[200]!),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _showHelpCard = !_showHelpCard),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('¿Cómo leer esta pantalla e interpretar ROP?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.blue[200] : Colors.blue[800])),
                    ),
                    Icon(_showHelpCard ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: !_showHelpCard ? const SizedBox.shrink() : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '• ROP (Punto de Reorden): Nivel mínimo de stock. Si tu stock cae a este valor o menos, debes pedir producto de inmediato.\n'
                      '• Velocidad: Si un producto rota lento, se muestra en unidades al mes (ej. 1.1/mes) o al día.\n'
                      '• Personaliza tu OC: Marca o desmarca productos con la casilla y usa los botones (+ / -) para modificar las cantidades antes de exportar el PDF.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Todo está en orden', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'No hay productos que coincidan con el filtro seleccionado.', 
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LISTA SLIVER INTERACTIVA DE PRODUCTOS (SELECCIÓN Y AJUSTE +/-)
  // =========================================================================
  Widget _buildSliverList(bool isDark) {
    final filtered = _filteredItems;

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = filtered[index];
            return _buildProductCard(item, isDark);
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(SmartRestockItem item, bool isDark) {
    final bool isCritical = item.status == 'agotado' || item.status == 'critico';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isSelected 
              ? Colors.blueAccent.withValues(alpha: 0.5) 
              : (isDark ? Colors.white10 : Colors.grey[200]!),
          width: item.isSelected ? 1.5 : 1.0,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: item.isSelected ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Checkbox, Nombre Descomprimido y Badge Semántico
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: item.isSelected,
                    activeColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        item.isSelected = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ProductNomenclatureLabel(
                    nombre: item.productName,
                    marca: item.brandName,
                    presentacion: item.presentationName,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: item.statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    item.statusText,
                    style: TextStyle(color: item.statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fila de Métricas: Stock, Velocidad y ROP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricColumn(
                      'Stock', 
                      '${item.currentStock}', 
                      isCritical ? Colors.redAccent : (item.currentStock == 0 ? Colors.red[900] : null), 
                      "Unidades disponibles para vender ahora mismo.",
                    ),
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: _buildMetricColumn(
                      'Velocidad', 
                      item.velocityDisplay, 
                      Colors.blueAccent, 
                      "Ritmo de venta promedio en los últimos 30 días.",
                    ),
                  ),
                  Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: _buildMetricColumn(
                      'ROP', 
                      '${item.rop}', 
                      Colors.orangeAccent, 
                      "Punto de Reorden: Nivel de stock donde debes solicitar compra para no quebrar existencias.",
                    ),
                  ),
                ],
              ),
            ),
            
            // Fecha de Agotamiento (si aplica)
            if (item.stockoutDate.isNotEmpty && item.daysToStockout <= 365) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 15, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Agotamiento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(item.stockoutDate))} (en ${item.daysToStockout.ceil()} días)',
                        style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Fila: Costo Unitario + Botón Trazabilidad Dedicado (Sin choque en 360dp)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Costo Unitario o Alerta de Costo 0
                if (item.hasZeroCost) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showAssignCostModal(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 13, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            "Sin costo • Asignar",
                            style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "Costo est.: ${AppCurrency.format(item.cost)}",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],

                // Botón Trazabilidad Claro y Separado
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (_) => AuditTrailScreen(
                            presentationId: item.presentationId, 
                            productId: item.productId, 
                            productName: (item.presentationName.trim().isNotEmpty && item.presentationName.trim() != 'Unidad')
                                ? '${item.productName} • ${item.presentationName.trim()}'
                                : item.productName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 13, color: Colors.blueAccent),
                          SizedBox(width: 4),
                          Text(
                            "Trazabilidad",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Control de Cantidad a Pedir (+/-) y Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "Pedir:",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    _buildQtyStepper(item),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Subtotal OC", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      AppCurrency.format(item.orderQty * item.cost),
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.bold, 
                        color: item.isSelected ? Colors.blueAccent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyStepper(SmartRestockItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              if (item.orderQty > 1) {
                setState(() => item.orderQty--);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              "${item.orderQty} und",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() => item.orderQty++);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color? valueColor, String tooltipText) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showInfoDialog(label, tooltipText),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 3),
              const Icon(Icons.info_outline, size: 11, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value, 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(String title, String explanation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(explanation, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  // =========================================================================
  // BARRA INFERIOR DE RESUMEN: TRI-STATE REACTIVO Y REGLA TÉCNICA 4
  // =========================================================================
  Widget _buildSummaryBar(bool isDark) {
    final visibleItems = _filteredItems;
    final selectedVisibleItems = visibleItems.where((i) => i.isSelected).toList();
    final bool allVisibleSelected = visibleItems.isNotEmpty && selectedVisibleItems.length == visibleItems.length;
    final bool someVisibleSelected = selectedVisibleItems.isNotEmpty && !allVisibleSelected;

    final selectedItems = _items.where((i) => i.isSelected).toList();
    final double totalInvestment = selectedItems.fold(0.0, (sum, item) => sum + (item.orderQty * item.cost));
    final int zeroCostSelectedCount = selectedItems.where((i) => i.hasZeroCost).length;

    IconData triStateIcon;
    String triStateLabel;

    if (allVisibleSelected) {
      triStateIcon = Icons.check_box;
      triStateLabel = "Deseleccionar todos (${selectedVisibleItems.length} de ${visibleItems.length})";
    } else if (someVisibleSelected) {
      triStateIcon = Icons.indeterminate_check_box;
      triStateLabel = "${selectedVisibleItems.length} de ${visibleItems.length} seleccionados";
    } else {
      triStateIcon = Icons.check_box_outline_blank;
      triStateLabel = "Seleccionar vista (${visibleItems.length})";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila de selección masiva sincronizada contextual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (allVisibleSelected) {
                        for (var i in visibleItems) {
                          i.isSelected = false;
                        }
                      } else {
                        // Si hay selección parcial (⊟) o ninguna (☐), seleccionar todos los de esta vista
                        for (var i in visibleItems) {
                          i.isSelected = true;
                        }
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        triStateIcon,
                        size: 20,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        triStateLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${selectedItems.length} de ${_items.length} para pedir",
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
            if (zeroCostSelectedCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    "$zeroCostSelectedCount item(s) sin costo asignado no suman al total",
                    style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inversión Total Sugerida', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      AppCurrency.format(totalInvestment),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: selectedItems.isEmpty ? null : _exportOC, // REGLA TÉCNICA 4: Deshabilitado si 0 seleccionados
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Exportar OC'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// DELEGATE PINNED PARA BUSCADOR Y CHIPS (REGLA TÉCNICA 3: FONDO SÓLIDO Y EXACTITUD)
// =========================================================================
class _StickySearchAndFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String currentFilter;
  final ValueChanged<String> onFilterSelected;
  final List<SmartRestockItem> items;
  final bool isDark;

  const _StickySearchAndFilterHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.currentFilter,
    required this.onFilterSelected,
    required this.items,
    required this.isDark,
  });

  @override
  double get minExtent => 98.0;

  @override
  double get maxExtent => 98.0;

  @override
  bool shouldRebuild(covariant _StickySearchAndFilterHeaderDelegate oldDelegate) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.currentFilter != currentFilter ||
        oldDelegate.items != items ||
        oldDelegate.isDark != isDark;
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    Color? color,
  }) {
    bool isSelected = currentFilter == filterKey;
    Color effectiveColor = color ?? Colors.blueAccent;

    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      selectedColor: effectiveColor,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey[300]!),
        ),
      ),
      onSelected: (_) => onFilterSelected(filterKey),
    );
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final porPedirCount = items.where((i) => i.status != 'saludable' || i.suggestedQty > 0).length;
    final urgentesCount = items.where((i) => i.status == 'agotado' || i.status == 'critico').length;
    final preventivosCount = items.where((i) => i.status == 'preventivo').length;
    final saludablesCount = items.where((i) => i.status == 'saludable').length;

    return Container(
      height: 98.0,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), // Fondo 100% sólido del Scaffold
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Buscador rápido (height 38)
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "Buscar producto por nombre o marca...",
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Fila de chips acotada estrictamente con SizedBox(height: 38)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip(
                  label: "✓ Por Pedir ($porPedirCount)",
                  filterKey: 'por_pedir',
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "🚨 Urgentes ($urgentesCount)",
                  filterKey: 'urgentes',
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "🟠 Preventivos ($preventivosCount)",
                  filterKey: 'preventivos',
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "🟢 Saludables ($saludablesCount)",
                  filterKey: 'saludables',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: "Todos (${items.length})",
                  filterKey: 'todos',
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
