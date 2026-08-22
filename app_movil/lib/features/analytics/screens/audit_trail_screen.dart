import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/database/local_db.dart';

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
  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    setState(() => _isLoading = true);
    try {
      final data = await _biService.getAuditTrail(widget.presentationId, widget.productId);
      
      final db = await LocalDatabase.instance.database;
      final pp = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [widget.presentationId]);
      int stock = 0;
      if (pp.isNotEmpty) {
        stock = (pp.first['stock_actual'] as num?)?.toInt() ?? 0;
      }

      if (mounted) {
        setState(() {
          _history = data;
          _currentStock = stock;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trazabilidad"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(isDark),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text("No hay registros en el historial."))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            return _buildTimelineItem(item, isDark, index == _history.length - 1);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Stock Actual: $_currentStock und',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Trazabilidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: Text(
                    "Esta pantalla muestra el historial completo de movimientos de tu producto: cada venta, compra, ajuste manual y cambio de precio. Los colores te indican si el stock entró (verde) o salió (rojo).",
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    )
                  ],
                )
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline, color: Colors.white, size: 28),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, bool isDark, bool isLast) {
    bool isStockOp = item['source_type'] == 'STOCK_OP';
    String rawAction = item['accion'] ?? 'Desconocido';
    DateTime date = DateTime.tryParse(item['fecha'].toString()) ?? DateTime.now();
    String formattedDate = DateFormat('dd MMM yyyy - HH:mm').format(date);
    String formattedTime = DateFormat('HH:mm').format(date);

    IconData icon;
    Color color;
    String displayAction;

    if (isStockOp) {
      int qty = (item['cantidad'] as num?)?.toInt() ?? 0;
      if (rawAction == 'VENTA') {
        icon = Icons.shopping_cart_checkout;
        color = Colors.redAccent;
        displayAction = '📦 Venta en Caja';
      } else if (rawAction == 'INVENTARIO_INICIAL') {
        icon = Icons.flag;
        color = Colors.blue;
        displayAction = '🏁 Punto de Partida';
      } else if (rawAction == 'COMPRA_LOTE') {
        icon = Icons.local_shipping;
        color = Colors.green;
        displayAction = '🚚 Ingreso por Factura';
      } else if (rawAction == 'AJUSTE_INVENTARIO' || rawAction == 'AJUSTE_MANUAL' || rawAction == 'AJUSTE') {
        if (qty > 0) {
          icon = Icons.add_circle_outline;
          color = Colors.green;
          displayAction = '➕ Ajuste Manual (+)';
        } else {
          icon = Icons.remove_circle_outline;
          color = Colors.redAccent;
          displayAction = '➖ Ajuste Manual (-)';
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
        displayAction = '💰 Precio de Venta Actualizado';
      } else if (rawAction == 'costo_unitario_calculado') {
        icon = Icons.analytics;
        color = Colors.purpleAccent;
        displayAction = '📊 Costo Interno Ajustado';
      } else if (rawAction == 'estado') {
        icon = Icons.visibility;
        color = Colors.orangeAccent;
        displayAction = '🔒 Visibilidad Cambiada';
      } else if (rawAction == 'marca_id' || rawAction == 'categoria_id') {
        icon = Icons.label;
        color = Colors.grey;
        displayAction = '🏷️ Clasificación Modificada';
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
                      color: isDark ? Colors.white12 : Colors.grey[300]
                    )
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                        Expanded(child: Text(displayAction, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color))),
                        Text(formattedTime, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isStockOp) ...[
                      Row(
                        children: [
                          Icon(Icons.tag, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            "Cantidad involucrada: ${((item['cantidad'] as num?)?.toInt() ?? 0) > 0 ? '+' : ''}${item['cantidad']}", 
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold,
                              color: ((item['cantidad'] as num?)?.toInt() ?? 0) > 0 ? Colors.green : Colors.redAccent
                            )
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text("${item['valor_anterior']}", style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough, color: Colors.grey))),
                            const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text("${item['valor_nuevo']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
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
}
