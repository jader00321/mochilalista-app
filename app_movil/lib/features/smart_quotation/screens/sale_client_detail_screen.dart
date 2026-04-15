import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers
import '../providers/sale_provider.dart';

// Widgets & Utilidades
import '../../../widgets/universal_image.dart';
import '../../../widgets/full_screen_image_viewer.dart';

// Widgets Modulares de Detalle (Reutilizamos los de solo lectura)
import '../widgets/history/detail_widgets/detail_header_card.dart';
import '../widgets/history/detail_widgets/detail_status_card.dart';

class SaleClientDetailScreen extends StatefulWidget {
  final int saleId;

  const SaleClientDetailScreen({super.key, required this.saleId});

  @override
  State<SaleClientDetailScreen> createState() => _SaleClientDetailScreenState();
}

class _SaleClientDetailScreenState extends State<SaleClientDetailScreen> {
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
    
    // Obtenemos los datos silenciosamente para no disparar loaders innecesarios en el provider
    final data = await provider.getSaleDetailSilently(widget.saleId);
    
    if (mounted) {
      setState(() {
        _saleData = data;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getOrigenStyles(String? origen, bool isDark) {
    if (origen == 'pos_rapido') {
      return {'label': "Compra en Caja Rápida", 'color': isDark ? Colors.pink[300] : Colors.pinkAccent, 'icon': Icons.point_of_sale};
    } else if (origen == 'ai_scan') {
      return {'label': "Compra Escaneada con IA", 'color': isDark ? Colors.purple[300] : Colors.purple, 'icon': Icons.auto_awesome};
    } else if (origen == 'client_web') {
      return {'label': "Pedido enviado por Web", 'color': isDark ? Colors.blue[300] : Colors.blue, 'icon': Icons.public};
    } else {
      return {'label': "Lista Cotizada Manualmente", 'color': isDark ? Colors.teal[300] : Colors.teal, 'icon': Icons.edit_note};
    }
  }

  Widget _buildLogisticsCard(bool isDark, Color cardColor) {
    final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
    String title = "Entregado al Instante";
    String subtitle = "Ya tienes tus productos en mano.";
    IconData icon = Icons.inventory_2;
    Color color = isDark ? Colors.green[400]! : Colors.green;

    if (deliveryStatus == 'retenido_por_pago') {
      title = "Retenido por Pago";
      subtitle = "Esperando la cancelación de deuda para entrega.";
      icon = Icons.lock_clock;
      color = isDark ? Colors.red[400]! : Colors.red;
    } else if (deliveryStatus == 'pendiente_recojo') {
      title = "Pendiente de Recojo";
      subtitle = "Tus productos están listos para recoger en tienda.";
      icon = Icons.storefront;
      color = isDark ? Colors.orange[400]! : Colors.orange;
    } else if (deliveryStatus == 'en_camino') {
      title = "En Camino (Delivery)";
      subtitle = "Tu paquete ya fue despachado.";
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    if (_saleData == null) {
      return Scaffold(
        backgroundColor: bgColor, 
        appBar: AppBar(
          title: Text("Detalle de Compra", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor),
        ), 
        body: const Center(child: Text("Error al cargar la compra. Intenta de nuevo."))
      );
    }

    final cotizacion = _saleData!['cotizacion'] ?? {};
    final items = cotizacion['items'] as List<dynamic>? ?? [];
    
    // Obtenemos el origen visual correcto
    final origenVenta = _saleData!['origen_venta'] ?? cotizacion['type'];
    final styles = _getOrigenStyles(origenVenta, isDark);
    
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy - hh:mm a');
    final String dateString = _saleData!['fecha_venta'] != null ? dateFormat.format(DateTime.parse(_saleData!['fecha_venta'])) : "";

    final String imageUrl = cotizacion['source_image_url'] ?? "";
    final double totalAmount = (_saleData!['monto_total'] ?? 0).toDouble();
    final double paidAmount = (_saleData!['monto_pagado'] ?? 0).toDouble();
    
    double pendingDebt = totalAmount - paidAmount;
    if (pendingDebt < 0) pendingDebt = 0;
    
    final List<dynamic> cuotasRaw = _saleData!['cuotas'] ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Mi Recibo #${_saleData!['id'].toString().padLeft(5, '0')}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 20)),
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
              // 1. Cabecera (Total y Origen)
              DetailHeaderCard(
                saleData: _saleData!,
                styles: styles,
                totalAmount: totalAmount,
                dateString: dateString,
                isDark: isDark,
              ),

              const SizedBox(height: 16),
              
              // 2. Tarjeta exclusiva de Logística (Solo lectura)
              _buildLogisticsCard(isDark, cardColor),

              // 3. Tarjeta de Deuda Resumida (Solo si hay deuda)
              if (pendingDebt > 0)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14141C) : Colors.red[50], 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text("Saldo Pendiente a Pagar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.red[800], fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(currency.format(pendingDebt), style: TextStyle(color: isDark ? Colors.redAccent : Colors.red[700], fontSize: 36, fontWeight: FontWeight.bold)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Costo Total", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700], fontSize: 13)),
                              Text(currency.format(totalAmount), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Abonado", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700], fontSize: 13)),
                              Text(currency.format(paidAmount), style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green[700], fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),

              // 4. Reutilizamos el DetailStatusCard para mostrar las cuotas de forma bonita
              DetailStatusCard(
                saleData: _saleData!,
                totalAmount: totalAmount,
                paidAmount: paidAmount,
                pendingDebt: pendingDebt,
                cuotasRaw: cuotasRaw,
                isDark: isDark,
              ),

              // 5. Botón para ver la imagen original si se escaneó
              if (imageUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 0, color: isDark ? Colors.purple.withOpacity(0.15) : Colors.purple.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.purple.withOpacity(0.3) : Colors.purple.shade200)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      leading: Icon(Icons.image, color: isDark ? Colors.purple[200] : Colors.purple, size: 30), 
                      title: Text("Ver lista física escaneada", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.purple[100] : Colors.purple)), 
                      trailing: Icon(Icons.arrow_forward_ios, size: 20, color: isDark ? Colors.purple[200] : Colors.purple),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, tag: "evidence_${_saleData!['id']}"))),
                    ),
                  ),
                ),

              // 6. Lista de Productos
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text("Productos Adquiridos (${items.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
              ),
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final double unitPrice = (item['unit_price_applied'] ?? 0.0).toDouble();
                  final double originalPrice = (item['original_unit_price'] ?? unitPrice).toDouble();
                  final int qty = item['quantity'] ?? 1;
                  final double itemSubtotal = unitPrice * qty;
                  final String imgUrl = item['image_url'] ?? "";
                  final bool hadDiscount = originalPrice > unitPrice + 0.01;

                  bool isStructured = item['product_name'] != null && item['product_name'].toString().isNotEmpty;

                  return Container(
                    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 55, height: 55,
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), 
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: imgUrl.isNotEmpty ? UniversalImage(path: imgUrl, fit: BoxFit.cover) : Icon(Icons.inventory_2, color: isDark ? Colors.grey[600] : Colors.grey, size: 30))
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              if (isStructured) ...[
                                if (item['brand_name'] != null && item['brand_name'].toString().isNotEmpty)
                                   Text(item['brand_name'].toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                                
                                Text(item['product_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                                
                                if (item['specific_name'] != null && item['specific_name'].toString().isNotEmpty)
                                   Padding(
                                     padding: const EdgeInsets.only(top: 2),
                                     child: Text(item['specific_name'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.teal[300] : Colors.teal[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                   ),
                              ] else ...[
                                Text(item['product_name_snapshot'] ?? 'Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis), 
                              ],
                              
                              const SizedBox(height: 10), 
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                    child: Text("Cant: $qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor))
                                  ),
                                  if (isStructured && item['sales_unit'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: Text(item['sales_unit'].toString().toUpperCase(), style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (hadDiscount) Text(currency.format(originalPrice), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(currency.format(unitPrice), style: TextStyle(color: hadDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontSize: 13, fontWeight: hadDiscount ? FontWeight.bold : FontWeight.normal)),
                                ],
                              )
                            ]
                          )
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 85,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(currency.format(itemSubtotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor)),
                              ),
                            ],
                          ),
                        )
                      ],
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
}