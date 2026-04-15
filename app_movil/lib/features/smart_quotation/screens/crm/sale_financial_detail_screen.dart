import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/sale_provider.dart';
import '../sale_history_detail_screen.dart'; 

class SaleFinancialDetailScreen extends StatefulWidget {
  final int saleId;

  const SaleFinancialDetailScreen({super.key, required this.saleId});

  @override
  State<SaleFinancialDetailScreen> createState() => _SaleFinancialDetailScreenState();
}

class _SaleFinancialDetailScreenState extends State<SaleFinancialDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _saleData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final data = await provider.getSaleDetail(widget.saleId);
    if (mounted) {
      setState(() {
        _saleData = data;
        _isLoading = false;
      });
    }
  }

  void _showChangeStatusDialog(String currentStatus, bool isDark) {
    String selectedStatus = currentStatus;
    final dialogBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.local_shipping, color: isDark ? Colors.blue[300] : Colors.blue, size: 28),
            const SizedBox(width: 12),
            Text("Estado Logístico", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Selecciona el nuevo estado de entrega:", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 16),
                _buildRadioTile("Entregado al instante", 'entregado', selectedStatus, Icons.inventory_2, isDark ? Colors.green[400]! : Colors.green, isDark, (val) => setDialogState(() => selectedStatus = val)),
                _buildRadioTile("Pendiente de Recojo", 'pendiente_recojo', selectedStatus, Icons.storefront, isDark ? Colors.orange[400]! : Colors.orange, isDark, (val) => setDialogState(() => selectedStatus = val)),
                _buildRadioTile("En Camino (Delivery)", 'en_camino', selectedStatus, Icons.delivery_dining, isDark ? Colors.purple[300]! : Colors.purple, isDark, (val) => setDialogState(() => selectedStatus = val)),
                _buildRadioTile("Retenido por Pago", 'retenido_por_pago', selectedStatus, Icons.lock_clock, isDark ? Colors.red[400]! : Colors.red, isDark, (val) => setDialogState(() => selectedStatus = val)),
              ],
            );
          }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final provider = Provider.of<SaleProvider>(context, listen: false);
              final success = await provider.updateDeliveryStatus(widget.saleId, selectedStatus);
              
              if (success) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logística actualizada", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
                await _loadData(); 
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.red));
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Guardar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Widget _buildRadioTile(String title, String value, String groupValue, IconData icon, Color color, bool isDark, Function(String) onChanged) {
    bool isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
        border: Border.all(color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade300)),
        borderRadius: BorderRadius.circular(14)
      ),
      child: RadioListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15, color: isSelected ? color : (isDark ? Colors.white : Colors.black87)))),
          ],
        ),
        value: value,
        groupValue: groupValue,
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onChanged: (val) => onChanged(val.toString()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading && _saleData == null) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    if (_saleData == null) {
      return Scaffold(backgroundColor: bgColor, appBar: AppBar(), body: const Center(child: Text("Error cargando venta")));
    }

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final double total = double.parse(_saleData!['monto_total'].toString());
    final double pagado = double.parse(_saleData!['monto_pagado'].toString());
    
    double saldo = total - pagado;
    if (saldo <= 0.02) saldo = 0.0;

    final List<dynamic> cuotas = _saleData!['cuotas'] ?? [];
    final cotizacion = _saleData!['cotizacion'] ?? {};
    final items = cotizacion['items'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Detalle de Venta #${widget.saleId}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Colors.blue[800],
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(saleId: widget.saleId)));
                  },
                  icon: const Icon(Icons.receipt_long, size: 22),
                  label: const Text("Ver Comprobante / Compartir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),

              _buildLogisticsCard(isDark, cardColor),

              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141C) : Colors.blueGrey[900], 
                  borderRadius: BorderRadius.circular(20), 
                  border: isDark ? Border.all(color: Colors.white10) : null,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    const Text("Saldo Pendiente de esta Venta", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(currency.format(saldo), style: TextStyle(color: saldo == 0 ? Colors.greenAccent : Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Costo Total", style: TextStyle(color: Colors.white54, fontSize: 13)),
                            Text(currency.format(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Abonado", style: TextStyle(color: Colors.white54, fontSize: 13)),
                            Text(currency.format(pagado), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),

              if (cuotas.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text("Cronograma de Pagos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cuotas.length,
                  itemBuilder: (ctx, i) {
                    final c = cuotas[i];
                    final double cMonto = double.parse(c['monto'].toString());
                    final double cPagado = double.parse((c['monto_pagado'] ?? 0.0).toString());
                    
                    double cSaldo = cMonto - cPagado;
                    bool isPaid = c['estado'] == 'pagado';
                    String displayEstado = c['estado'].toString().toUpperCase();

                    if (cSaldo <= 0.02) {
                      cSaldo = 0.0;
                      isPaid = true;
                      displayEstado = 'PAGADO';
                    }
                    
                    Color statusColor = isDark ? Colors.orange[300]! : Colors.orange;
                    if (isPaid) {
                      statusColor = isDark ? Colors.green[400]! : Colors.green;
                    } else if (cPagado > 0) statusColor = isDark ? Colors.blue[300]! : Colors.blue;

                    return Card(
                      elevation: 0,
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: textColor,
                          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
                          leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.15), child: Icon(isPaid ? Icons.check : Icons.calendar_month, color: statusColor)),
                          title: Text("Cuota ${c['numero_cuota']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          subtitle: Text("Vence: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']))}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currency.format(cMonto), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
                              Text(displayEstado, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Total Cuota: ${currency.format(cMonto)}", style: TextStyle(fontSize: 14, color: textColor)),
                                      const SizedBox(height: 4),
                                      Text("Abonado: ${currency.format(cPagado)}", style: TextStyle(fontSize: 14, color: isDark ? Colors.green[400] : Colors.green)),
                                      const SizedBox(height: 4),
                                      Text("Falta Pagar: ${currency.format(cSaldo)}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                )
              ] else ...[
                 Center(child: Padding(padding: const EdgeInsets.all(24), child: Text("Esta venta se realizó al contado (Sin cuotas)", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 15, fontStyle: FontStyle.italic))))
              ],

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text("Productos Adquiridos (${items.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return Card(
                    elevation: 0,
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(Icons.check_box, color: isDark ? Colors.green[400] : Colors.green),
                      title: Text(item['product_name_snapshot'] ?? "Producto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                      subtitle: Text("Cantidad: ${item['quantity']}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      trailing: Text(currency.format(item['unit_price_applied'] * item['quantity']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    ),
                  );
                }
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogisticsCard(bool isDark, Color cardColor) {
    final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
    String title = "Entregado al Instante";
    String subtitle = "El cliente ya tiene sus productos.";
    IconData icon = Icons.inventory_2;
    Color color = isDark ? Colors.green[400]! : Colors.green;

    if (deliveryStatus == 'retenido_por_pago') {
      title = "Retenido por Pago";
      subtitle = "Esperando cancelación de deuda.";
      icon = Icons.lock_clock;
      color = isDark ? Colors.red[400]! : Colors.red;
    } else if (deliveryStatus == 'pendiente_recojo') {
      title = "Pendiente de Recojo";
      subtitle = "Programado para entregar.";
      icon = Icons.storefront;
      color = isDark ? Colors.orange[400]! : Colors.orange;
    } else if (deliveryStatus == 'en_camino') {
      title = "En Camino (Delivery)";
      subtitle = "Paquete despachado.";
      icon = Icons.local_shipping;
      color = isDark ? Colors.purple[300]! : Colors.purple;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Logística: $title", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 24),
            color: color,
            tooltip: "Modificar Estado",
            onPressed: () => _showChangeStatusDialog(deliveryStatus, isDark), 
          )
        ],
      ),
    );
  }
}