import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart'; 
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart'; 

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
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
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
              final provider = Provider.of<SaleProvider>(context, listen: false);
              
              String? fotoPath;
              if (selectedStatus == 'entregado' && currentStatus != 'entregado') {
                 // Preguntar si desea tomar foto
                 bool? takePhoto = await showDialog<bool>(
                   context: context,
                   builder: (ctx2) => AlertDialog(
                     backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     title: Row(
                       children: [
                         Icon(Icons.camera_alt, color: Colors.blue[600], size: 28),
                         const SizedBox(width: 10),
                         Expanded(child: Text("Evidencia de Entrega", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
                       ],
                     ),
                     content: Text("Recomendamos tomar una foto de los productos o de la guía firmada. ¿Deseas capturarla ahora?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
                     actions: [
                       TextButton(
                         onPressed: () => Navigator.pop(ctx2, false), 
                         child: Text("No, solo marcar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))
                       ),
                       ElevatedButton(
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                         onPressed: () => Navigator.pop(ctx2, true),
                         child: const Text("Sí, tomar foto")
                       )
                     ],
                   )
                 );

                 if (takePhoto == true) {
                   final ImagePicker picker = ImagePicker();
                   final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                   if (image != null) {
                     try {
                       // Guardar permanentemente
                       final Directory appDocDir = await getApplicationDocumentsDirectory();
                       final String newPath = p.join(appDocDir.path, 'entrega_${widget.saleId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
                       final File savedImage = await File(image.path).copy(newPath);
                       fotoPath = savedImage.path;
                     } catch (e) {
                       debugPrint("Error guardando foto: $e");
                     }
                   }
                 }
              }

              if (!mounted) return;
              setState(() => _isLoading = true);
              final success = await provider.updateDeliveryStatus(widget.saleId, selectedStatus, fotoPath: fotoPath);
              
              if (success) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logística actualizada"), backgroundColor: Colors.green));
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
        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade300)),
        borderRadius: BorderRadius.circular(14)
      ),
      child: IgnorePointer(
        ignoring: false,
        child: RadioListTile(
          title: Row(
            children: [
              Icon(icon, size: 20, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15, color: isSelected ? color : (isDark ? Colors.white : Colors.black87)))),
            ],
          ),
          value: value,
          // ignore: deprecated_member_use
          groupValue: groupValue,
          activeColor: color,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          // ignore: deprecated_member_use
          onChanged: (val) => onChanged(val.toString()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading && _saleData == null) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    if (_saleData == null) {
      return Scaffold(backgroundColor: bgColor, appBar: AppBar(), body: const Center(child: Text("Error cargando venta")));
    }

    // 🔥 Parseo double seguro desde SQLite
    final double baseTotal = (num.tryParse(_saleData!['monto_total'].toString()) ?? 0.0).toDouble();
    final double pagado = (num.tryParse(_saleData!['monto_pagado'].toString()) ?? 0.0).toDouble();
    final double interes = (num.tryParse(_saleData!['porcentaje_interes']?.toString() ?? '0') ?? 0.0).toDouble();
    final double moraTotal = (num.tryParse((_saleData!['mora_total'] ?? 0.0).toString()) ?? 0.0).toDouble();
    final double total = baseTotal;

    double saldo = total - pagado;
    if (saldo <= 0.02) saldo = 0.0;

    final List<dynamic> cuotas = _saleData!['cuotas'] ?? [];
    final items = _saleData!['items'] as List<dynamic>? ?? [];
    final bool isLoan = _saleData!['origen_venta'] == 'prestamo_personal';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isLoan
                ? "Detalle del Préstamo #${_saleData?['numero_secuencial'] ?? widget.saleId}"
                : "Detalle de Venta #${_saleData?['numero_secuencial'] ?? widget.saleId}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            tooltip: "Ver PDF",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(
                    quotationId: _saleData?['cotizacion_id'] ?? 0,
                    saleId: widget.saleId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
            tooltip: "Enviar WhatsApp",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WhatsAppPreviewScreen(
                    quotationId: _saleData?['cotizacion_id'] ?? 0,
                    saleId: widget.saleId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
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

              if (!isLoan)
                _buildLogisticsCard(isDark, cardColor),

              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141C) : Colors.blueGrey[900], 
                  borderRadius: BorderRadius.circular(20), 
                  border: isDark ? Border.all(color: Colors.white10) : null,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.1 * 255).toInt()), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    Text(isLoan ? "Saldo Pendiente de este Préstamo" : "Saldo Pendiente de esta Venta", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (interes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.orange.withAlpha((0.2 * 255).toInt()), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withAlpha((0.5 * 255).toInt()))),
                        child: Text("Interés aplicado: ${interes.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    if (moraTotal > 0.01)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.red.withAlpha((0.2 * 255).toInt()), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withAlpha((0.5 * 255).toInt()))),
                        child: Text("Mora acumulada: + ${AppCurrency.format(moraTotal)}", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    Text(AppCurrency.format(saldo), style: TextStyle(color: saldo == 0 ? Colors.greenAccent : Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isLoan ? "Monto Total" : "Costo Total", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            Text(AppCurrency.format(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Abonado", style: TextStyle(color: Colors.white54, fontSize: 13)),
                            Text(AppCurrency.format(pagado), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    final double cMonto = (num.tryParse(c['monto'].toString()) ?? 0.0).toDouble();
                    final double cPagado = (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
                    final double cMontoOriginal = (num.tryParse((c['monto_original'] ?? cMonto).toString()) ?? cMonto).toDouble();
                    final double cMoraMonto = (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
                    final double cMoraPorcentaje = (num.tryParse((c['mora_porcentaje'] ?? 0.0).toString()) ?? 0.0).toDouble();
                    final bool isAutoMora = (c['mora_automatica'] == 1 || c['mora_automatica'] == true);
                    
                    double cSaldo = cMonto - cPagado;
                    bool isPaid = c['estado'] == 'pagado';
                    String displayEstado = c['estado'].toString().toUpperCase();

                    if (cSaldo <= 0.02) {
                      cSaldo = 0.0;
                      isPaid = true;
                      displayEstado = 'PAGADA';
                    }
                    
                    final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
                    final DateTime dueDate = CuotaDateHelper.parseFlexible(c['fecha_vencimiento']) ?? DateTime.now();
                    final bool isOverdue = !isPaid && dateInfo.isPast;
                    final int daysOverdue = dateInfo.daysOverdue;

                    Color statusColor = isDark ? Colors.grey[400]! : Colors.grey;
                    IconData statusIcon = Icons.calendar_today;
                    String statusText = displayEstado;

                    if (isPaid) {
                      statusColor = isDark ? Colors.green[300]! : Colors.green.shade700;
                      statusIcon = Icons.check_circle_rounded;
                      statusText = 'PAGADA';
                    } else {
                      if (isOverdue) {
                        statusColor = isDark ? Colors.red[300]! : Colors.red.shade700;
                        statusIcon = Icons.warning_amber_rounded;
                        statusText = 'VENCIDA';
                      } else if (dateInfo.isToday) {
                        statusColor = isDark ? Colors.amber[300]! : Colors.amber.shade800;
                        statusIcon = Icons.notification_important_outlined;
                        statusText = 'VENCE HOY';
                      } else if (dateInfo.daysDifference >= -3) {
                        statusColor = isDark ? Colors.orange[300]! : Colors.orange.shade800;
                        statusIcon = Icons.schedule_rounded;
                        statusText = 'PRÓXIMA';
                      } else if (cPagado > 0) {
                        statusColor = isDark ? Colors.blue[300]! : Colors.blue.shade700;
                        statusIcon = Icons.payments_rounded;
                        statusText = 'PARCIAL';
                      } else {
                        statusColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
                        statusIcon = Icons.hourglass_top_rounded;
                        statusText = 'PENDIENTE';
                      }
                    }

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
                          leading: CircleAvatar(backgroundColor: statusColor.withValues(alpha: 0.15), child: Icon(statusIcon, color: statusColor)),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Cuota ${c['numero_cuota']}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                              ),
                              if (isAutoMora) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 11, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                                      const SizedBox(width: 2),
                                      Text(
                                        "Auto",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.amber[300] : Colors.amber[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isOverdue ? "Venció hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'}" : dateInfo.fullLabel,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isOverdue ? (isDark ? Colors.red[300] : Colors.red.shade800) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                if (cMoraMonto > 0.01) ...[
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: (isDark ? Colors.amber : Colors.orange).withValues(alpha: 0.3), width: 0.7),
                                      ),
                                      child: Text(
                                        "Base: ${AppCurrency.format(cMontoOriginal)} • + Mora: ${AppCurrency.format(cMoraMonto)} (${cMoraPorcentaje.toStringAsFixed(1)}%)",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.amber[300] : Colors.orange[900],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppCurrency.format(cMonto),
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Tabla Financiera Limpia de 4 Filas
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildFinancialRow("Monto Base:", AppCurrency.format(cMontoOriginal), isDark: isDark),
                                        const SizedBox(height: 6),
                                        _buildFinancialRow(
                                          "Recargo por Mora:",
                                          cMoraMonto > 0.01 ? "+ ${AppCurrency.format(cMoraMonto)}" : "S/ 0.00",
                                          valueColor: cMoraMonto > 0.01 ? (isDark ? Colors.redAccent : Colors.red) : null,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 6),
                                        _buildFinancialRow(
                                          "Monto Abonado:",
                                          AppCurrency.format(cPagado),
                                          valueColor: isDark ? Colors.greenAccent : Colors.green.shade700,
                                          isDark: isDark,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 6),
                                          child: Divider(height: 1, thickness: 0.8),
                                        ),
                                        _buildFinancialRow(
                                          "Saldo Exigible Cuota:",
                                          AppCurrency.format(cSaldo),
                                          isBold: true,
                                          valueColor: cSaldo <= 0.02
                                              ? (isDark ? Colors.greenAccent : Colors.green)
                                              : (isDark ? Colors.redAccent : Colors.red),
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (!isPaid) ...[
                                    const SizedBox(height: 12),
                                    // Barra unificada de 4 acciones simétricas
                                    Row(
                                      children: [
                                        // 1. [📅 Fecha]
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () async {
                                              final newDate = await showDatePicker(
                                                context: context,
                                                initialDate: dueDate,
                                                firstDate: DateTime.now().subtract(const Duration(days: 60)),
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                                builder: (context, child) {
                                                  return Theme(
                                                    data: isDark
                                                        ? ThemeData.dark().copyWith(
                                                            colorScheme: ColorScheme.dark(
                                                              primary: Colors.blue[300]!,
                                                              onPrimary: Colors.black,
                                                              surface: const Color(0xFF23232F),
                                                              onSurface: Colors.white,
                                                            ),
                                                          )
                                                        : ThemeData.light().copyWith(
                                                            colorScheme: ColorScheme.light(
                                                              primary: Colors.blue[800]!,
                                                              onPrimary: Colors.white,
                                                              surface: Colors.white,
                                                              onSurface: Colors.black,
                                                            ),
                                                          ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (newDate != null && newDate.isAtSameMomentAs(dueDate) == false) {
                                                setState(() => _isLoading = true);
                                                if (!context.mounted) return;
                                                final provider = Provider.of<SaleProvider>(context, listen: false);
                                                final success = await provider.updateInstallmentDate(
                                                  c['id'] as int,
                                                  newDate.toIso8601String(),
                                                  saleId: widget.saleId,
                                                );
                                                if (success) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text("Fecha actualizada exitosamente"), backgroundColor: Colors.green),
                                                    );
                                                  }
                                                  await _loadData();
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text("Error al actualizar la fecha"), backgroundColor: Colors.red),
                                                    );
                                                  }
                                                  setState(() => _isLoading = false);
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.8),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.calendar_month, size: 13, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      "Fecha",
                                                      style: TextStyle(
                                                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // 2. [⚙️ Mora / 🛡️ Prog. Mora]
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              CuotaMorosidadModal.show(
                                                context: context,
                                                cuota: c,
                                                isDark: isDark,
                                                onSaved: _loadData,
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: (cMoraMonto > 0.01 ? Colors.redAccent : (isOverdue ? Colors.orange : Colors.blueGrey)).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: (cMoraMonto > 0.01 ? Colors.redAccent : (isOverdue ? Colors.orange : Colors.blueGrey)).withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      cMoraMonto > 0.01 ? Icons.timer_outlined : (isOverdue ? Icons.tune : Icons.shield_outlined),
                                                      size: 13,
                                                      color: cMoraMonto > 0.01 ? Colors.redAccent : (isOverdue ? Colors.orange[800] : (isDark ? Colors.cyanAccent : Colors.teal)),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      cMoraMonto > 0.01 ? "Mora" : (isOverdue ? "Mora" : "Prog. Mora"),
                                                      style: TextStyle(
                                                        color: cMoraMonto > 0.01 ? Colors.redAccent : (isOverdue ? Colors.orange[800] : (isDark ? Colors.cyanAccent : Colors.teal)),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // 3. [💬 Recordar]
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              WhatsAppPreviewModal.showCuotaReminder(
                                                context: context,
                                                cuota: c,
                                                clientName: _saleData?['cliente_nombre'] ?? (_saleData?['cliente_info']?['nombre_completo']),
                                                clientPhone: _saleData?['cliente_telefono'] ?? (_saleData?['cliente_info']?['telefono']),
                                                isDark: isDark,
                                                operationTitle: isLoan ? "Préstamo" : "Venta a Crédito",
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3), width: 0.8),
                                              ),
                                              child: const FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.chat_bubble_outline, size: 13, color: Color(0xFF25D366)),
                                                    SizedBox(width: 3),
                                                    Text("Recordar", style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // 4. [💵 Cobrar]
                                        Expanded(
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () => _openCuotaPayment(c),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 0.8),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.payments_outlined, size: 13, color: isDark ? Colors.tealAccent[400] : Colors.teal.shade800),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      "Cobrar",
                                                      style: TextStyle(
                                                        color: isDark ? Colors.tealAccent[400] : Colors.teal.shade800,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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

              if (!isLoan) ...[
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
                  String brand = item['brand_name']?.toString() ?? "";
                  String prodName = item['product_name']?.toString() ?? "Producto";
                  String specificName = item['specific_name']?.toString() ?? "";
                  
                  String fullName = brand.isNotEmpty ? "[$brand] $prodName" : prodName;
                  if (specificName.isNotEmpty && specificName != 'null') fullName += " ($specificName)";
                  
                  String salesUnit = item['sales_unit']?.toString() ?? "Unidad";
                  double unitP = (num.tryParse(item['unit_price_applied']?.toString() ?? '0') ?? 0.0).toDouble();
                  double originalP = (num.tryParse(item['original_unit_price']?.toString() ?? '0') ?? unitP).toDouble();
                  int quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

                  String imageUrl = item['image_url']?.toString() ?? "";
                  String originalText = item['original_text']?.toString() ?? "";
                  
                  return Card(
                    elevation: 0,
                    color: cardColor,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(imageUrl, width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.inventory, color: isDark ? Colors.blueGrey[400] : Colors.blueGrey, size: 30)),
                            )
                          else
                            Container(
                              width: 45, height: 45,
                              decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.blueGrey[400] : Colors.blueGrey, size: 24),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                if (originalText.isNotEmpty && originalText != "null") ...[
                                  const SizedBox(height: 2),
                                  Text("Cotizado como: $originalText", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text("$quantity $salesUnit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700])),
                                    ),
                                    const SizedBox(width: 8),
                                    Text("x ${AppCurrency.format(unitP)}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                    if (originalP > unitP) ...[
                                      const SizedBox(width: 6),
                                      Text(AppCurrency.format(originalP), style: TextStyle(color: Colors.red[300], fontSize: 11, decoration: TextDecoration.lineThrough)),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(AppCurrency.format(unitP * quantity), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        ],
                      ),
                    )
                  );
                }
              ),
              ],
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

    final String? fotoEntrega = _saleData!['foto_entrega'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color, size: 24)),
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
          if (fotoEntrega != null && fotoEntrega.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(12)),
              child: TextButton.icon(
                icon: Icon(Icons.photo_camera, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                label: Text("Ver Foto de Entrega", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold)),
                onPressed: () {
                   showDialog(context: context, builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(fotoEntrega))
                      )
                   ));
                },
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[700];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: labelColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? textColor,
          ),
        ),
      ],
    );
  }

  void _openCuotaPayment(Map<String, dynamic> c) async {
    final int? clientId = _saleData?['cliente_id'] as int? ?? _saleData?['cliente_info']?['id'] as int?;
    if (clientId == null || clientId <= 0) return;
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final client = await saleProv.getClientById(clientId);
    if (client != null && mounted) {
      final double cuotaMonto = (num.tryParse(c['monto'].toString()) ?? 0.0).toDouble();
      final double cuotaPagado = (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      final double saldoCuota = cuotaMonto - cuotaPagado;

      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PaymentEntryModal(
          client: client,
          initialTargetType: 'cuota',
          initialTargetId: c['id'] as int?,
          initialAmount: saldoCuota > 0.01 ? saldoCuota : cuotaMonto,
          onPaymentSuccess: () {
            _loadData();
            saleProv.silentRefresh();
          },
        ),
      );
    }
  }
}