import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/widgets/product_nomenclature_label.dart';
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/analytics/services/purchase_order_generator.dart';
import 'package:share_plus/share_plus.dart';

class SmartRestockItem {
  final int presentationId;
  final int productId;
  final String productName;
  final String brandName;
  final String presentationName;
  final int currentStock;
  final double cost;
  final double velocityPerDay;
  final int safetyStock;
  final int rop;
  final int suggestedQty;
  final double daysToStockout;
  final String stockoutDate;

  SmartRestockItem({
    required this.presentationId,
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.presentationName,
    required this.currentStock,
    required this.cost,
    required this.velocityPerDay,
    required this.safetyStock,
    required this.rop,
    required this.suggestedQty,
    required this.daysToStockout,
    required this.stockoutDate,
  });
}

class SmartRestockScreen extends StatefulWidget {
  const SmartRestockScreen({super.key});

  @override
  State<SmartRestockScreen> createState() => _SmartRestockScreenState();
}

class _SmartRestockScreenState extends State<SmartRestockScreen> {
  final InventoryIntelligenceService _biService = InventoryIntelligenceService();
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  
  bool _isLoading = true;
  List<SmartRestockItem> _items = [];
  bool _showHelpCard = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = await LocalDatabase.instance.database;
      
      final products = await db.rawQuery('''
        SELECT pp.id as presentation_id, p.id as product_id, p.nombre, IFNULL(m.nombre, 'Sin Marca') as marca_nombre, 
               pp.nombre_especifico, pp.stock_actual, pp.costo_unitario_calculado
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [auth.activeBusinessId]);

      List<SmartRestockItem> results = [];
      
      for (var row in products) {
        int presId = row['presentation_id'] as int;
        int currentStock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        final biData = await _biService.calculateReorderPoint(presId, currentStock);
        
        int rop = (biData['rop'] as num).toInt();
        if (rop == 0) rop = 5; // Umbral crítico por defecto si no hay data de BI
        
        double vel = (biData['velocity_per_day'] as num).toDouble();
        double daysToStockout = (biData['days_to_stockout'] as num).toDouble();
        String stockoutDate = biData['stockout_date'] as String? ?? "";
        
        int suggestedQty = (biData['suggested_order_qty'] as num).toInt();
        if (suggestedQty == 0) suggestedQty = 10; // Cantidad base sugerida si no hay historial
        
        // Disparador: Predictivo (Stock <= ROP) o Reactivo Base (Stock <= 5)
        if (currentStock <= rop || currentStock <= 5) {
          results.add(SmartRestockItem(
            presentationId: presId,
            productId: row['product_id'] as int,
            productName: row['nombre'] as String,
            brandName: row['marca_nombre'] as String,
            presentationName: row['nombre_especifico'] as String? ?? 'Unidad',
            currentStock: currentStock,
            cost: (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0,
            velocityPerDay: vel,
            safetyStock: (biData['safety_stock'] as num).toInt(),
            rop: rop,
            suggestedQty: suggestedQty,
            daysToStockout: daysToStockout,
            stockoutDate: stockoutDate,
          ));
        }
      }
      
      // Ordenar por urgencia (los que están más por debajo del ROP primero)
      results.sort((a, b) {
        int deficitA = a.rop - a.currentStock;
        int deficitB = b.rop - b.currentStock;
        return deficitB.compareTo(deficitA); // Mayor déficit primero
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportOC() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final itemsToBuy = _items.where((i) => i.currentStock <= i.rop).toList();
      if (itemsToBuy.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay items críticos para ordenar')));
        return;
      }
      final file = await PurchaseOrderGenerator.exportToPdf(itemsToBuy, auth.businessName);
      if (!mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Orden de Compra Sugerida - ${auth.businessName}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Motor Inteligente de Abastecimiento', style: TextStyle(fontSize: 18)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar Orden de Compra',
            onPressed: _exportOC,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty 
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildHelpCard(isDark),
                    Expanded(child: _buildList(isDark)),
                  ],
                ),
      bottomNavigationBar: _items.isNotEmpty ? _buildSummaryBar(isDark) : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('Todo está en orden', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No hay productos que requieran abastecimiento.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHelpCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('¿Cómo leer esta pantalla?', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[200] : Colors.blue[800])),
                    ),
                    Icon(_showHelpCard ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: !_showHelpCard ? const SizedBox.shrink() : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Este motor analiza tu ritmo de ventas para predecir cuándo te quedarás sin stock.\n\n'
                      '🔴 Crítico: Tienes 5 unidades o menos. Reabastece urgente.\n'
                      '🟠 Preventivo: Tu stock está por debajo del Punto de Reorden (ROP).\n\n'
                      'Toca el icono (i) en cada métrica para más detalles, y usa "Exportar OC" para generar tu orden de compra en PDF.',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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

  Widget _buildList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        bool isCritical = item.currentStock <= 5;
        bool isPredictive = item.currentStock > 5 && item.currentStock <= item.rop;
        
        Color statusColor = isCritical ? Colors.redAccent : (isPredictive ? Colors.orangeAccent : Colors.green);
        String statusText = isCritical ? 'Stock Base Crítico' : (isPredictive ? 'Prevención Predictiva' : 'Saludable');
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ProductNomenclatureLabel(
                        nombre: item.productName,
                        marca: item.brandName,
                        presentacion: item.presentationName,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricColumn('Stock', '${item.currentStock}', isCritical ? Colors.redAccent : null, "Unidades disponibles para vender ahora mismo. Si llega a 0, pierdes ventas.")),
                    Expanded(child: _buildMetricColumn('Velocidad', '${item.velocityPerDay.toStringAsFixed(1)}/d', Colors.blueAccent, "Ritmo de ventas promedio: cuántas unidades vendes por día. Se calcula con tus ventas de los últimos 30 días.")),
                    Expanded(child: _buildMetricColumn('ROP', '${item.rop}', Colors.orangeAccent, "Punto de Reorden: Nivel mínimo de inventario. Si tu stock cae a este número, es momento de hacer tu pedido al proveedor.")),
                  ],
                ),
                
                if (item.stockoutDate.isNotEmpty && item.daysToStockout < 999) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_graph, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Agotamiento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(item.stockoutDate))} (en ${item.daysToStockout.ceil()} días)',
                            style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sugerido: ${item.suggestedQty} und',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.grey),
                          tooltip: 'Ver Trazabilidad',
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (_) => AuditTrailScreen(
                                  presentationId: item.presentationId, 
                                  productId: item.productId, 
                                  productName: item.productName
                                )
                              )
                            );
                          },
                        ),
                        Text(
                          _currencyFmt.format(item.suggestedQty * item.cost),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 12, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
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
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(explanation, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          )
        ],
      )
    );
  }

  Widget _buildSummaryBar(bool isDark) {
    // Solo contar los que necesitan compra sugerida real (stock <= rop)
    final itemsToBuy = _items.where((i) => i.currentStock <= i.rop).toList();
    double totalInvestment = itemsToBuy.fold(0.0, (sum, item) => sum + (item.suggestedQty * item.cost));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inversión Total Sugerida', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  _currencyFmt.format(totalInvestment),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ElevatedButton.icon(
                onPressed: _exportOC,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar OC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
