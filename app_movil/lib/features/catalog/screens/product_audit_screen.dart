import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';

class ProductAuditScreen extends StatefulWidget {
  final int presentationId;
  final int productId;
  final String productName;

  const ProductAuditScreen({
    super.key,
    required this.presentationId,
    required this.productId,
    required this.productName,
  });

  @override
  State<ProductAuditScreen> createState() => _ProductAuditScreenState();
}

class _ProductAuditScreenState extends State<ProductAuditScreen> {
  final InventoryIntelligenceService _biService = InventoryIntelligenceService();
  final NumberFormat _currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a', 'es_PE');
  
  bool _isLoading = true;
  final List<Map<String, dynamic>> _auditEvents = [];
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (!_hasMore) return;
    
    try {
      final newEvents = await _biService.getAuditTrail(
        widget.presentationId, 
        widget.productId,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _auditEvents.addAll(newEvents);
          _offset += _limit;
          _isLoading = false;
          if (newEvents.length < _limit) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event, bool isDark) {
    bool isStock = event['source_type'] == 'STOCK_OP';
    String action = event['accion'].toString();
    DateTime date = DateTime.tryParse(event['fecha'].toString()) ?? DateTime.now();

    IconData icon;
    Color iconColor;
    String title;
    String description;

    if (isStock) {
      int qty = (event['cantidad'] as num?)?.toInt() ?? 0;
      double cost = (event['costo_unitario'] as num?)?.toDouble() ?? 0.0;
      double price = (event['precio_venta'] as num?)?.toDouble() ?? 0.0;

      if (action == 'VENTA') {
        icon = Icons.shopping_cart_checkout; iconColor = Colors.redAccent;
        title = '📦 Venta en Caja';
        description = "Salida de ${qty.abs()} unidades.";
      } else if (action == 'INVENTARIO_INICIAL') {
        icon = Icons.flag; iconColor = Colors.blue;
        title = '🏁 Punto de Partida';
        description = "Inventario inicial de $qty unidades.\nCosto: ${_currencyFmt.format(cost)} | Precio: ${_currencyFmt.format(price)}";
      } else if (action == 'COMPRA_LOTE') {
        icon = Icons.local_shipping; iconColor = Colors.green;
        title = '🚚 Ingreso por Factura';
        description = "Ingresaron $qty unidades.\nCosto Registrado: ${_currencyFmt.format(cost)}";
      } else if (action == 'AJUSTE_INVENTARIO' || action == 'AJUSTE_MANUAL' || action == 'AJUSTE') {
        if (qty > 0) {
          icon = Icons.add_circle_outline; iconColor = Colors.green;
          title = '➕ Ajuste Manual (+)';
          description = "Agregadas ${qty.abs()} unidades manualmente.";
        } else {
          icon = Icons.remove_circle_outline; iconColor = Colors.redAccent;
          title = '➖ Ajuste Manual (-)';
          description = "Descontadas ${qty.abs()} unidades manualmente.";
        }
      } else {
        icon = Icons.swap_horiz; iconColor = Colors.grey;
        title = "Movimiento: $action";
        description = "Variación de $qty unidades.";
      }
    } else {
      String oldVal = event['valor_anterior']?.toString() ?? "N/A";
      String newVal = event['valor_nuevo']?.toString() ?? "N/A";

      if (action == 'precio_venta_final') {
        icon = Icons.price_change; iconColor = Colors.purpleAccent;
        title = '💰 Precio de Venta Actualizado';
        description = "El precio cambió de S/ $oldVal a S/ $newVal";
      } else if (action == 'costo_unitario_calculado') {
        icon = Icons.analytics; iconColor = Colors.purpleAccent;
        title = '📊 Costo Interno Ajustado';
        description = "El costo interno cambió de S/ $oldVal a S/ $newVal";
      } else if (action == 'estado') {
        icon = Icons.visibility; iconColor = Colors.orangeAccent;
        title = '🔒 Visibilidad Cambiada';
        description = "De: $oldVal\nA: $newVal";
      } else if (action == 'marca_id' || action == 'categoria_id') {
        icon = Icons.label; iconColor = Colors.grey;
        title = '🏷️ Clasificación Modificada';
        description = "De: $oldVal\nA: $newVal";
      } else {
        icon = Icons.edit_note; iconColor = Colors.teal;
        title = "Campo '$action' Modificado";
        description = "De: $oldVal\nA: $newVal";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Node
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withValues(alpha: 0.5), width: 2),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 4),
              Container(
                width: 2,
                height: 50,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              )
            ],
          ),
          const SizedBox(width: 16),
          // Event Card
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateFmt.format(date), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(description, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Auditoría de Producto', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Trazabilidad Inmutable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue)),
                const SizedBox(height: 8),
                Text(
                  widget.productName,
                  style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  "Historial de todos los cambios de stock y configuración.",
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading && _auditEvents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _auditEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 60, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text("No hay eventos registrados aún."),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (!_isLoading && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                            _loadEvents();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _auditEvents.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _auditEvents.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildTimelineEvent(_auditEvents[index], isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
